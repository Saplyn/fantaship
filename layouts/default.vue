<template>
  <div class="flex flex-col w-full h-full">
    <nav
      class="flex shrink-0 z-50 text-green-900 font-bold text-xl items-center justify-between bg-green-300 w-full h-20 px-20"
    >
      <!-- Routes -->
      <div class="flex items-center justify-center gap-5">
        <NuxtLink v-for="item in routes" :to="item.path">
          <div>{{ item.name }}</div>
        </NuxtLink>
      </div>

      <!-- Account -->
      <div class="flex items-center justify-center gap-5">
        <NuxtLink v-for="item in accountRoutes" :to="item.path">
          <div>{{ item.name }}</div>
        </NuxtLink>
      </div>
    </nav>

    <div class="w-full overflow-auto px-20 grow h-full">
      <slot />
    </div>
  </div>
</template>

<script lang="ts" setup>
type NavItem = {
  name: string;
  path: string;
};

const routes: NavItem[] = [
  { name: "软件包", path: "/" },
  { name: "发布软件", path: "/publish" },
  { name: "我的订阅", path: "/subscription" },
];

const accountRoutes: NavItem[] = [
  { name: "开发账户", path: "/developer" },
  { name: "受众账户", path: "/audience" },
];
</script>

<style></style>
