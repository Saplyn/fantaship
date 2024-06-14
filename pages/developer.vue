<template>
  <div class="h-full pt-10">
    <!-- Login -->
    <div
      v-if="devToken == undefined"
      class="flex h-full w-full flex-col items-center gap-4 pt-10"
    >
      <p class="mb-2 text-2xl font-bold text-green-900">登录或注册开发者账户</p>
      <IconField icon-position="right">
        <InputIcon class="pi pi-user" />
        <InputText v-model="devCred.name" placeholder="用户名" />
      </IconField>

      <Password
        v-model="devCred.pswd"
        :feedback="false"
        placeholder="用户密码"
        toggle-mask
      />

      <div class="flex items-center justify-center gap-4">
        <Button @click="devSignIn">登录</Button>
        <Button @click="devSignUp">注册</Button>
      </div>
    </div>

    <!-- Developer Info -->
    <div v-else>
      <div class="flex items-center justify-center gap-6 pt-10">
        <p class="text-2xl font-bold text-green-900">
          已作为开发者 {{ devName }} 登入
        </p>
        <Button @click="devSignOut" severity="danger">登出</Button>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import Surreal from "surrealdb.js";

const toasts = useToast();

// LYN: Developer Account

const devToken = useCookie<string | undefined>("devToken");
const devName = useCookie<string | undefined>("devName");
const devConn = new Surreal();
const devCred = ref<DeveloperCredential>({ name: "", pswd: "" });
await devConn.connect("http://localhost:8000/rpc", {
  namespace: "main",
  database: "main",
});
if (devToken.value != undefined) {
  await devAuth(false);
}

async function devSignIn() {
  console.log("dev signin with cred:", devCred.value);

  await devConn
    .signin({
      namespace: "main",
      database: "main",
      scope: "developer",
      name: devCred.value.name,
      pswd: devCred.value.pswd,
    })
    .then(async (res) => {
      console.log("signin success:", res);
      devToken.value = res;
      await devAuth();
    })
    .catch((err) => {
      console.log("signin failed:", err);
      toasts.add({
        severity: "error",
        summary: "登录失败",
        detail: "请检查用户名和密码",
        life: 4000,
      });
    });
}

async function devSignUp() {
  console.log("dev signup with cred:", devCred.value);

  await devConn
    .signup({
      namespace: "main",
      database: "main",
      scope: "developer",
      name: devCred.value.name,
      pswd: devCred.value.pswd,
    })
    .then(async (res) => {
      console.log("signup success:", res);
      devToken.value = res;
      await devAuth();
    })
    .catch((err) => {
      console.error("signup failed:", err);
      toasts.add({
        severity: "error",
        summary: "注册失败",
        detail: "用户名存在或凭据非法",
        life: 4000,
      });
    });
}

async function devAuth(showToast = true) {
  console.log("dev auth with token:", devToken.value);

  if (devToken.value == undefined) {
    toasts.add({
      severity: "error",
      summary: "认证失败",
      detail: "请先登录或注册",
      life: 4000,
    });
    return;
  }

  makeAuth(devConn, devToken.value)
    .then(() => {
      devCred.value.pswd = "";

      if (devName.value == undefined) {
        devName.value = devCred.value.name;
      }
      if (showToast) {
        toasts.add({
          severity: "success",
          summary: "认证成功",
          life: 4000,
        });
      }
    })
    .catch(() => {
      devToken.value = undefined;
      toasts.add({
        severity: "error",
        summary: "认证失败",
        detail: "请重新登录",
        life: 4000,
      });
    });
}

async function devSignOut() {
  console.log("dev signout");

  await devConn
    .invalidate()
    .then((res) => {
      console.log("invalidate success:", res);
      devToken.value = undefined;
      devName.value = undefined;
      toasts.add({
        severity: "success",
        summary: "登出成功",
        life: 4000,
      });
    })
    .catch((err) => {
      console.error("invalidate failed:", err);
      toasts.add({
        severity: "error",
        summary: "登出失败",
        detail: "出现未知错误",
        life: 4000,
      });
    });
}
</script>

<style></style>
