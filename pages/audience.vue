<template>
  <div class="h-full pt-10">
    <!-- Login -->
    <div
      v-if="audToken == undefined"
      class="flex h-full w-full flex-col items-center gap-4 pt-10"
    >
      <p class="mb-2 text-2xl font-bold text-green-900">登录或注册受众账户</p>
      <IconField icon-position="right">
        <InputIcon class="pi pi-user" />
        <InputText v-model="audCred.name" placeholder="用户名" />
      </IconField>

      <Password
        v-model="audCred.pswd"
        :feedback="false"
        placeholder="用户密码"
        toggle-mask
      />

      <div class="flex items-center justify-center gap-4">
        <Button @click="audSignIn">登录</Button>
        <Button @click="audSignUp">注册</Button>
      </div>
    </div>

    <!-- Audience Info -->
    <div v-else>
      <div class="flex items-center justify-center gap-6 pt-10">
        <p class="text-2xl font-bold text-green-900">
          已作为受众用户 {{ audName }} 登入
        </p>
        <Button @click="audSignOut" severity="danger">登出</Button>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
import Surreal, { RecordId } from "surrealdb.js";

const toasts = useToast();

// LYN: Audience Account

const audToken = useCookie<string | undefined>("audToken");
const audName = useCookie<string | undefined>("audName");
const audId = useCookie<RecordId | undefined>("audId");
const audConn = new Surreal();
const audCred = ref<AudienceCredential>({ name: "", pswd: "" });
await audConn.connect("http://localhost:8000/rpc", {
  namespace: "main",
  database: "main",
});
if (audToken.value != undefined) {
  await audAuth(false);
}

async function audSignIn() {
  console.log("aud signin with cred:", audCred.value);

  await audConn
    .signin({
      namespace: "main",
      database: "main",
      scope: "audience",
      name: audCred.value.name,
      pswd: audCred.value.pswd,
    })
    .then(async (res) => {
      console.log("signin success:", res);
      audToken.value = res;
      await audAuth();
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

async function audSignUp() {
  console.log("aud signup with cred:", audCred.value);

  await audConn
    .signup({
      namespace: "main",
      database: "main",
      scope: "audience",
      name: audCred.value.name,
      pswd: audCred.value.pswd,
    })
    .then(async (res) => {
      console.log("signup success:", res);
      audToken.value = res;
      await audAuth();
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

async function audAuth(showToast = true) {
  console.log("aud auth with token:", audToken.value);

  if (audToken.value == undefined) {
    toasts.add({
      severity: "error",
      summary: "认证失败",
      detail: "请先登录或注册",
      life: 4000,
    });
    return;
  }

  makeAuth(audConn, audToken.value)
    .then(async () => {
      audCred.value.pswd = "";

      if (audName.value == undefined) {
        audName.value = audCred.value.name;
        await audConn
          .info()
          .then((res) => {
            audId.value = res!.id;
          })
          .catch((err) => {
            console.error("info failed:", err);
          });
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
      audToken.value = undefined;
      toasts.add({
        severity: "error",
        summary: "认证失败",
        detail: "请重新登录",
        life: 4000,
      });
    });
}

async function audSignOut() {
  console.log("aud signout");

  await audConn
    .invalidate()
    .then((res) => {
      console.log("invalidate success:", res);
      audToken.value = undefined;
      audName.value = undefined;
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
