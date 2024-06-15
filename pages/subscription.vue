<template>
  <div class="pt-10">
    <div
      v-if="audToken == undefined"
      class="flex flex-col items-center justify-center gap-8 pt-10"
    >
      <p class="text-3xl font-bold text-green-900">未登录为软件受众</p>
      <Button label="前往登录" @click="navigateTo('/audience')" />
    </div>

    <div class="grid grid-cols-2 gap-4" v-else>
      <div
        v-for="p in mySubscription"
        class="rounded-xl bg-green-200 px-6 py-4"
      >
        <div class="flex items-center justify-between">
          <div class="flex flex-col gap-1">
            <p class="text-3xl font-bold text-green-900">{{ p.name }}</p>
            <p class="text-sm text-green-900/50">{{ p.pid }}</p>
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
  </div>
</template>

<script lang="ts" setup>
import { RecordId, Surreal } from "surrealdb.js";

const audConn = new Surreal();
const audToken = useCookie<string | undefined>("audToken");
const audId = useCookie<RecordId | undefined>("audId");
await audConn.connect("http://localhost:8000/rpc", {
  namespace: "main",
  database: "main",
});
if (audToken.value != undefined) {
  makeAuth(audConn, audToken.value).catch(() => {
    audToken.value = undefined;
  });

  // HACK: don't know how but first query always fails
  await useProbe(audConn);
}

const mySubscription = ref<PackageFull[]>([]);
async function retrieveSubscription() {
  audConn
    .query<PackageFull[][]>(
      "SELECT VALUE ->subscribe->available_package AS package FROM ONLY (type::thing($tb, $id)) FETCH package, source, install;",
      {
        tb: audId.value!.toString().split(":")[0],
        id: audId.value!.toString().split(":")[1],
      },
    )
    .then((res) => {
      console.log("query success:", res[0]);
      mySubscription.value = res[0];
    })
    .catch((err) => {
      console.error("query failed:", err);
      console.error("query failed:", err.message);
    });
}
if (audToken.value != undefined) {
  await retrieveSubscription();
}

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
</script>

<style></style>
