import Surreal from "surrealdb.js";

export const useProbe = async (conn: Surreal) => {
  await conn
    .query("RETURN true;")
    .then((res) => {
      console.log("probe success:", res);
    })
    .catch((err) => {
      console.error("probe failed:", err);
    });
};
