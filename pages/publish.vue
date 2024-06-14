<template>
  <div class="h-full pt-10">
    <div
      v-if="devToken == undefined"
      class="flex flex-col items-center justify-center gap-8 pt-10"
    >
      <p class="text-3xl font-bold text-green-900">未登录为开发者</p>
      <Button label="前往登录" @click="navigateTo('/developer')" />
    </div>

    <div v-else>
      <div
        class="sticky top-0 flex h-20 w-full items-center justify-center gap-4 bg-gradient-to-r from-green-200/0 via-green-200 to-green-200/0"
      >
        <InputGroup class="w-96">
          <InputText
            v-model="newPackageName"
            placeholder="软件包名称"
            ref="newPackageNameRef"
          />
          <Button
            icon="pi pi-upload"
            label="发布草稿"
            @click="publishPackge"
            :disabled="newPackageName.length === 0"
            icon-pos="right"
          />
        </InputGroup>
      </div>

      <div class="flex flex-col items-center justify-center gap-5 pt-10">
        <div
          v-for="p in myPackages"
          class="flex h-28 w-7/12 items-center justify-between rounded-xl bg-green-200 p-5"
        >
          <div class="flex flex-col gap-1">
            <p class="text-3xl font-bold text-green-900">{{ p.name }}</p>
            <p class="text-sm text-green-900/50">{{ p.id! }}</p>
          </div>
          <div class="flex gap-5">
            <Button @click="editPackage(p)">修改</Button>
            <Button severity="danger" @click="removePackage(p)">删除</Button>
          </div>
        </div>
      </div>
    </div>

    <!-- Update Package Dialog -->
    <Dialog
      v-model:visible="editPackageDialogVisible"
      class="max-w-[60%]"
      modal
      header="编辑软件包"
    >
      <div class="flex flex-col">
        <div class="mb-10 text-gray-800/30">
          正在编辑 {{ editingPackage!.id! }}
        </div>
        <div class="flex flex-col gap-3">
          <!-- Source -->
          <div class="grid grid-cols-3">
            <p class="col-span-1 flex items-center justify-end px-5">安装源</p>
            <Dropdown
              class="col-span-2"
              v-model="selectedSource"
              option-label="name"
              :options="availableSources"
              checkmark
            />
          </div>
          <!-- Source/GitHub -->
          <Fieldset
            v-if="selectedSource.code == 'github'"
            legend="GitHub Release"
          >
            <div class="grid grid-cols-3 gap-2">
              <p class="col-span-1 flex items-center justify-end px-5">
                Github 仓库所有者
              </p>
              <InputText
                class="col-span-2"
                v-model="githubSource.owner"
                placeholder="Github 仓库所有者"
              />
              <p class="col-span-1 flex items-center justify-end px-5">
                Github 仓库名称
              </p>
              <InputText
                class="col-span-2"
                v-model="githubSource.repo"
                placeholder="Github 仓库名称"
              />
              <p class="col-span-1 flex items-center justify-end px-5">
                版本号正则表达式
              </p>
              <InputText
                class="col-span-2"
                v-model="githubSource.v_regex"
                placeholder="版本号正则表达式"
              />
            </div>
          </Fieldset>

          <!-- Source/Git -->
          <Fieldset v-if="selectedSource.code == 'git'" legend="Git 仓库">
            <div class="grid grid-cols-3 gap-2">
              <p class="col-span-1 flex items-center justify-end px-5">
                Git 仓库地址
              </p>
              <InputText
                class="col-span-2"
                v-model="gitSource.origin"
                placeholder="Git 仓库地址"
              />
            </div>
          </Fieldset>

          <!-- Extract -->
          <div class="grid grid-cols-3">
            <p class="col-span-1 flex items-center justify-end px-5">
              解压方式
            </p>
            <Dropdown
              class="col-span-2"
              v-model="selectedExtract"
              :options="availableExtracts"
              option-label="name"
              checkmark
            />
          </div>

          <!-- Install -->
          <div class="grid grid-cols-3">
            <p class="col-span-1 flex items-center justify-end px-5">
              安装方式
            </p>
            <Dropdown
              class="col-span-2"
              v-model="selectedInstall"
              :options="availableInstalls"
              option-label="name"
              checkmark
            />
          </div>

          <!-- Install/Executable -->
          <Fieldset
            v-if="selectedInstall.code == 'executable'"
            legend="可执行程序"
          >
            <div class="grid grid-cols-3 gap-2">
              <p class="col-span-1 flex items-center justify-end px-5">
                目标文件名
              </p>
              <InputText
                class="col-span-2"
                v-model="executableInstall.target"
                placeholder="目标文件名"
              />

              <p class="col-span-1 flex items-center justify-end px-5">
                重命名
              </p>
              <ToggleButton
                v-model="executableRenameCheck"
                :class="executableRenameCheck ? 'col-span-1' : 'col-span-2'"
                offLabel="不重命名"
                onLabel="重命名为"
              />
              <InputText
                class="col-span-1"
                v-if="executableRenameCheck"
                v-model="executableInstall.rename"
                placeholder="重命名"
              />
            </div>
          </Fieldset>

          <div class="flex items-center justify-center">
            <Button
              icon="pi pi-pen-to-square"
              label="提交更改"
              @click="submitEdit"
            />
          </div>
        </div>
      </div>
    </Dialog>
  </div>
</template>

<script lang="ts" setup>
import { defaultOptions } from "primevue/config";
import type Fieldset from "primevue/fieldset";
import Surreal from "surrealdb.js";

const toasts = useToast();

// LYN: UI

const newPackageNameRef = ref<HTMLInputElement | null>(null);
const { focused: newPackageNameFocus } = useFocus(newPackageNameRef);
onKeyStroke("Enter", (e) => {
  if (newPackageNameFocus.value) {
    publishPackge();
  }
});

// LYN: Publish Package

const devConn = new Surreal();
const devToken = useCookie<string | undefined>("devToken");
await devConn.connect("http://localhost:8000/rpc", {
  namespace: "main",
  database: "main",
});
if (devToken.value != undefined) {
  makeAuth(devConn, devToken.value).catch(() => {
    devToken.value = undefined;
  });

  // HACK: don't know how but first query always fails
  await useProbe(devConn);
}

const newPackageName = ref<string>("");

async function publishPackge() {
  console.log("publishing package to portal:", newPackageName.value);

  await devConn
    .insert<PublishPackageReq>("portal_publish", {
      name: newPackageName.value,
    })
    .then(async (res) => {
      console.log("publish success:", res);
      toasts.add({
        severity: "success",
        summary: "发布成功",
        detail: `软件包 ${newPackageName.value} 已发布为草稿`,
        life: 4000,
      });

      newPackageName.value = "";
      await retrievePackages();
    })
    .catch((err) => {
      console.log("publish failed:", err);
    });
}

// LYN: Developer Packages

const myPackages = ref<Package[]>([]);
if (devToken.value != undefined) {
  await retrievePackages();
}

async function retrievePackages() {
  console.log("retrieving developer packages");
  await devConn
    .select<Package>("package")
    .then((res) => {
      console.log("select success:", res);
      myPackages.value = res;
    })
    .catch((err) => {
      console.error("select failed:", err);
    });
}

// LYN: Remove Package

async function removePackage(p: Package) {
  console.log("removing package:", p);

  await devConn
    .delete(p.id!)
    .then(async (res) => {
      console.log("delete success:", res);
      toasts.add({
        severity: "success",
        summary: "删除成功",
        detail: `软件包 ${p.name} 已删除`,
        life: 4000,
      });

      await retrievePackages();
    })
    .catch((err) => {
      console.error("delete failed:", err);
    });
}

// LYN: Edit Package

const editPackageDialogVisible = ref<boolean>(false);
const editingPackage = ref<Package | null>(null);

const SOURCE_NONE = { name: "未设置", code: undefined };
const SOURCE_GITHUB = { name: "GitHub Release", code: "github" };
const SOURCE_GIT = { name: "Git 仓库", code: "git" };

const availableSources = ref([SOURCE_NONE, SOURCE_GITHUB, SOURCE_GIT]);
const selectedSource = ref<
  typeof SOURCE_NONE | typeof SOURCE_GITHUB | typeof SOURCE_GIT
>(SOURCE_NONE);
const githubSource = ref<SourceGithubRaw>({
  repo: "",
  owner: "",
  v_regex: "",
});
const gitSource = ref<SourceGitRaw>({
  origin: "",
});

const EXTRACT_NONE = { name: "不解压", code: undefined };
const EXTRACT_TAR = { name: "Tar", code: "tar" };
const EXTRACT_ZIP = { name: "Zip", code: "zip" };
const EXTRACT_RAR = { name: "Rar", code: "rar" };
const availableExtracts = ref([
  EXTRACT_NONE,
  EXTRACT_TAR,
  EXTRACT_ZIP,
  EXTRACT_RAR,
]);
const selectedExtract = ref<
  | typeof EXTRACT_NONE
  | typeof EXTRACT_TAR
  | typeof EXTRACT_ZIP
  | typeof EXTRACT_RAR
>(EXTRACT_NONE);

const INSTALL_NONE = { name: "未设置", code: undefined };
const INSTALL_EXECUTABLE = { name: "可执行程序", code: "executable" };
const availableInstalls = ref([INSTALL_NONE, INSTALL_EXECUTABLE]);
const selectedInstall = ref<typeof INSTALL_NONE | typeof INSTALL_EXECUTABLE>(
  INSTALL_NONE,
);
const executableInstall = ref<InstallExecutableRaw>({
  target: "",
  rename: undefined,
});
const executableRenameCheck = ref<boolean>(false);
watch(executableRenameCheck, (checked) => {
  if (checked) {
    console.log("rename checked");
    if (executableInstall.value.rename == undefined) {
      executableInstall.value.rename = "";
    }
  } else {
    console.log("rename unchecked");
    executableInstall.value.rename = undefined;
  }
});

const originalSource = ref<UnknownRecord>();
const originalInstall = ref<UnknownRecord>();

async function editPackage(p: Package) {
  console.log("editing package:", p);

  editingPackage.value = p;
  editPackageDialogVisible.value = true;

  const pid = p.id!.toString();

  console.log("getting source for:", pid);
  await devConn
    .query(`SELECT source.* FROM ONLY ${pid};`)
    .then((res) => {
      let src = res as any[];
      console.log("get package source success:", src[0].source);
      originalSource.value = src[0].source as UnknownRecord;
    })
    .catch((err) => {
      console.error("get package source failed:", err);
    });

  console.log("getting install for:", pid);
  await devConn
    .query(`SELECT install.* FROM ONLY ${pid};`)
    .then((res) => {
      let ins = res as any[];
      console.log("get package install success:", ins[0].install);
      originalInstall.value = ins[0].install as UnknownRecord;
    })
    .catch((err) => {
      console.error("get package install failed:", err);
    });

  // LYN: Source
  switch (p.source?.tb) {
    case "github":
      selectedSource.value = SOURCE_GITHUB;
      githubSource.value = originalSource.value as SourceGithubRaw;
      break;
    case "git":
      selectedSource.value = SOURCE_GIT;
      gitSource.value = originalSource.value as SourceGitRaw;
      break;
    default:
      selectedSource.value = SOURCE_NONE;
  }
  // LYN: Install
  switch (p.install?.tb) {
    case "executable":
      selectedInstall.value = INSTALL_EXECUTABLE;
      executableInstall.value = originalInstall.value as InstallExecutableRaw;
      if (executableInstall.value.rename == undefined) {
        executableRenameCheck.value = false;
      } else {
        executableRenameCheck.value = true;
      }
      break;
    default:
      selectedInstall.value = INSTALL_NONE;
  }
  // LYN: Extract
  switch (p.extract) {
    case "tar":
      selectedExtract.value = EXTRACT_TAR;
      break;
    case "zip":
      selectedExtract.value = EXTRACT_ZIP;
      break;
    case "rar":
      selectedExtract.value = EXTRACT_RAR;
      break;
    default:
      selectedExtract.value = EXTRACT_NONE;
  }
}

async function submitEdit() {
  console.log("submitting edit for package:", editingPackage.value!.id!);

  console.log("original source:", originalSource.value);
  console.log("original install:", originalInstall.value);

  // LYN: Source
  const originalSourceTb = originalSource.value?.id?.tb;
  if (originalSourceTb == selectedSource.value.code) {
    if (originalSourceTb != undefined) {
      console.log("update original source");

      let src = undefined;
      switch (selectedSource.value.code) {
        case "github":
          src = githubSource.value;
          break;
        case "git":
          src = gitSource.value;
          break;
        default:
          console.error("unreachable code: submitEdit()/source");
      }

      console.log(
        `UPDATE ${originalSource.value!.id!.toString()} MERGE ${intoMergeObjectString(src)};`,
      );
      await devConn
        .query(
          `UPDATE ${originalSource.value!.id!.toString()} MERGE ${intoMergeObjectString(src)};`,
        )
        .then((res) => {
          console.log("merge source success:", res);
        })
        .catch((err) => {
          console.error("merge source failed:", err);
        });
    } else {
      console.log("source remain undefined");
    }
  } else {
    if (originalSourceTb != undefined) {
      console.log("delete original source");

      console.log("deleting source:", originalSource.value!.id!.toString());
      await devConn
        .query(`DELETE ${originalSource.value!.id!.toString()};`)
        .then((res) => {
          console.log("delete source success:", res);
        })
        .catch((err) => {
          console.error("delete source failed:", err);
        });
    }

    if (selectedSource.value.code != undefined) {
      console.log("create new source");

      let src = undefined;
      switch (selectedSource.value.code) {
        case "github":
          console.log("github source:", githubSource.value);
          src = githubSource.value;
          break;
        case "git":
          console.log("git source:", gitSource.value);
          src = gitSource.value;
          break;
        default:
          console.error("unreachable code: submitEdit()/source");
      }

      console.log("creating source:", src);
      console.log("table id:", selectedSource.value.code);
      await devConn
        .create(selectedSource.value.code, {
          package: editingPackage.value!.id,
          ...src,
        })
        .then((res) => {
          console.log("insert source success:", res);
        })
        .catch((err) => {
          console.error("insert source failed:", err);
        });
    }
  }

  // LYN: Install
  const originalInstallTb = originalInstall.value?.id?.tb;
  if (originalInstallTb == selectedInstall.value.code) {
    if (originalInstallTb != undefined) {
      console.log("update original install");

      let ins = undefined;
      switch (selectedInstall.value.code) {
        case "executable":
          ins = executableInstall.value;
          break;
        default:
          console.error("unreachable code: submitEdit()/install");
      }

      console.log(
        `UPDATE ${originalInstall.value!.id!.toString()} MERGE ${intoMergeObjectString(ins)};`,
      );
      await devConn
        .query(
          `UPDATE ${originalInstall.value!.id!.toString()} MERGE ${intoMergeObjectString(ins)};`,
        )
        .then((res) => {
          console.log("merge install success:", res);
        })
        .catch((err) => {
          console.error("merge install failed:", err);
        });
    } else {
      console.log("install remain undefined");
    }
  } else {
    if (originalInstallTb != undefined) {
      console.log("delete original install");

      await devConn
        .query(`DELETE ${originalInstall.value!.id!.toString()};`)
        .then((res) => {
          console.log("delete install success:", res);
        })
        .catch((err) => {
          console.error("delete install failed:", err);
        });
    }

    if (selectedInstall.value.code != undefined) {
      console.log("create new install");

      let ins = undefined;
      switch (selectedInstall.value.code) {
        case "executable":
          ins = executableInstall.value;
          break;
        default:
          console.error("unreachable code: submitEdit()/install");
      }

      console.log("lyn debug:", selectedInstall.value.code);
      console.log("lyn debug:", {
        package: editingPackage.value!.id,
        ...ins,
      });
      console.log(
        `CREATE ${selectedInstall.value.code} CONTENT ${intoMergeObjectString({
          package: editingPackage.value!.id,
          ...ins,
        })}`,
      );
      await devConn
        .create(selectedInstall.value.code, {
          package: editingPackage.value!.id,
          ...ins,
        })
        .then((res) => {
          console.log("insert install success:", res);
        })
        .catch((err) => {
          console.error("insert install failed:", err);
        });
    }
  }

  // LYN: Extract
  console.log(
    `UPDATE ${editingPackage.value!.id!} SET extract = ${intoMergeString(selectedExtract.value.code)};`,
  );
  devConn
    .query(
      `UPDATE ${editingPackage.value!.id!} SET extract = ${intoMergeString(selectedExtract.value.code)};`,
    )
    .then((res) => {
      console.log("merge extract success:", res);
    })
    .catch((err) => {
      console.error("merge extract failed:", err);
    });

  // LYN: Refresh
  await retrievePackages();
  toasts.add({
    severity: "success",
    summary: "提交成功",
    detail: `软件包 ${editingPackage.value!.name} 已更新`,
    life: 4000,
  });
}

// LYN: Util

function intoMergeObjectString(obj: any) {
  let str = "{";
  for (const key in obj) {
    let val = obj[key];
    if (typeof val === "string") val = `"${val}"`;
    if (val == undefined) val = "NONE";
    str += `${key}: ${val}, `;
  }
  str += "}";
  return str;
}

function intoMergeString(str: string | undefined): string {
  if (str == undefined) {
    return "NONE";
  } else {
    return `"${str}"`;
  }
}
</script>

<style></style>
