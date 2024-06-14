import Surreal from "surrealdb.js";

export const makeAuth = async (conn: Surreal, token: string) => {
  await conn
    .authenticate(token)
    .then((res) => {
      console.log("auth success:", res);
    })
    .catch((err) => {
      console.error("auth failed:", err);
      throw err;
    });
};
