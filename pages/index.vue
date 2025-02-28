<template>
  <div class="flex flex-col items-center">
    <div
      class="sticky top-0 mt-10 flex h-20 w-full items-center justify-center bg-gradient-to-r from-green-200/0 via-green-200 to-green-200/0"
    >
      <InputGroup class="w-96">
        <InputText v-model="searchText" placeholder="搜索软件包" />
        <Button icon="pi pi-search" />
      </InputGroup>
    </div>

    <div class="flex w-full flex-col items-center justify-center gap-5 pt-10">
      <div
        v-for="p in packages"
        class="flex h-28 w-7/12 items-center justify-between rounded-xl bg-green-200 p-5"
      >
        <div class="flex gap-4">
          <Button
            icon="pi pi-bookmark"
            v-if="audToken != undefined"
            @click="subscribe(p.id!)"
          />
          <div class="flex flex-col gap-1">
            <p class="text-3xl font-bold text-green-900">{{ p.name }}</p>
            <p class="text-sm text-green-900/50">{{ p.pid }}</p>
          </div>
        </div>

        <div
          class="flex flex-col items-end justify-center gap-1 overflow-visible text-xs"
        >
          <div class="flex flex-row-reverse items-center gap-2">
            <p
              class="peer shrink-0 rounded-lg bg-emerald-500 px-2 py-1 text-white duration-75 ease-out hover:text-sm"
            >
              <i class="pi pi-cloud-download"></i> 软件发行
            </p>
            <p
              class="absolute -translate-x-20 rounded bg-green-400 px-2 py-1 text-green-900 opacity-0 duration-75 ease-out peer-hover:-translate-x-24 peer-hover:text-sm peer-hover:opacity-100"
            >
              {{ intoInstallString(p.install) }}
            </p>
          </div>

          <div class="flex flex-row-reverse items-center gap-2">
            <p
              class="peer shrink-0 rounded-lg bg-emerald-500 px-2 py-1 text-white duration-75 ease-out hover:text-sm"
            >
              <i class="pi pi-download"></i> 安装方式
            </p>
            <p
              class="absolute -translate-x-20 rounded bg-green-400 px-2 py-1 text-green-900 opacity-0 duration-75 ease-out peer-hover:-translate-x-24 peer-hover:text-sm peer-hover:opacity-100"
            >
              {{ intoSourceString(p.source) }}
            </p>
          </div>

          <div class="flex flex-row-reverse items-center gap-2">
            <p
              class="peer shrink-0 rounded-lg bg-emerald-500 px-2 py-1 text-white duration-75 ease-out hover:text-sm"
            >
              <i class="pi pi-info-circle"></i> 解压方式
            </p>
            <p
              class="absolute -translate-x-20 rounded bg-green-400 px-2 py-1 text-green-900 opacity-0 duration-75 ease-out peer-hover:-translate-x-24 peer-hover:text-sm peer-hover:opacity-100"
            >
              {{ intoExtractString(p.extract) }}
            </p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import Button from "primevue/button";
import InputGroup from "primevue/inputgroup";
import Surreal, { RecordId } from "surrealdb.js";

const toasts = useToast();
const audToken = useCookie<string | undefined>("audToken");
const audId = useCookie<RecordId | undefined>("audId");

const searchText = ref<string>("");

const packages = ref<PackageFull[]>([]);

const conn = new Surreal();
if (audToken.value != undefined) {
  await conn.connect("http://localhost:8000/rpc", {
    namespace: "main",
    database: "main",
  });
  await makeAuth(conn, audToken.value).catch((err) => {
    console.error("auth as audience failed:", err);
  });
} else {
  await conn.connect("http://localhost:8000/rpc", {
    namespace: "main",
    database: "main",
    auth: {
      namespace: "main",
      database: "main",
      scope: "guest",
      name: "guest",
    },
  });
}

await useProbe(conn);

conn
  .query<PackageFull[][]>(
    "SELECT * FROM available_package FETCH install, source;",
  )
  .then((res) => {
    console.log("query success:", res[0]);
    packages.value = res[0];
  })
  .catch((err) => {
    console.error("query failed:", err);
  });

// LYN: Utils

function intoInstallString(ins: UnknownRecord): string {
  switch (ins.id?.tb) {
    case "executable":
      let exe = ins as InstallExecutable;
      return `作为可执行文件 ${exe.target} 安装${exe.rename ? `并重命名为 ${exe.rename}` : ""}`;
    default:
      return "没有安装指引";
  }
}
function intoSourceString(src: UnknownRecord): string {
  switch (src.id?.tb) {
    case "github":
      let github = src as SourceGithub;
      return `该软件将从 GitHub ${github.owner}/${github.repo} 的 Release 获取`;
    case "git":
      let git = src as SourceGit;
      return `该软件的远端 Git 仓库为 ${git.origin}`;
    default:
      return "没有安装源说明";
  }
}
function intoExtractString(ext: string | undefined): string {
  if (ext == undefined) {
    return `不解压`;
  } else {
    return `作为 ${ext} 文件解压`;
  }
}

// LYN: Subscription

function subscribe(apid: RecordId) {
  if (audToken.value == undefined) {
    toasts.add({
      severity: "error",
      summary: "订阅失败",
      detail: "请先登录或注册为受众用户",
      life: 4000,
    });
    return;
  }

  conn
    .query(
      "RELATE (type::thing($audTb, $audId))->subscribe->(type::thing('available_package', $apId));",
      {
        audTb: audId.value?.toString().split(":")[0],
        audId: audId.value?.toString().split(":")[1],
        apId: apid,
      },
    )
    .then((res) => {
      console.log("subscribe success:", res);
      toasts.add({
        severity: "success",
        summary: "订阅成功",
        life: 4000,
      });
    })
    .catch((err) => {
      console.error("subscribe failed:", err);
      console.error("subscribe failed:", err.message);
      toasts.add({
        severity: "error",
        summary: "订阅失败",
        detail: "或已经订阅过该软件包",
        life: 4000,
      });
    });
}
</script>

<style></style>
