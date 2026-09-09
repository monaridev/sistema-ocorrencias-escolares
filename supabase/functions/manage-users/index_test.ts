import { handler } from "./index.ts";
function assert(value: boolean, message: string) {
  if (!value) throw new Error(message);
}
Deno.test("nega requisição sem identidade antes de acessar dados", async () => {
  const result = await handler(
    new Request("http://local", { method: "POST", body: "{}" }),
  );
  assert(result.status === 401, "401 esperado");
});
Deno.test("professor e gestor não podem administrar usuários", async () => {
  const original = globalThis.fetch;
  try {
    for (const role of ["professor", "gestor"]) {
      globalThis.fetch = async (input) =>
        new Response(
          JSON.stringify(
            String(input).endsWith("/auth/v1/user")
              ? { id: "u" }
              : [{ role, ativo: true }],
          ),
          { status: 200 },
        );
      const result = await handler(
        new Request("http://local", {
          method: "POST",
          headers: { Authorization: "Bearer teste" },
          body: JSON.stringify({ action: "create" }),
        }),
      );
      assert(result.status === 403, "403 esperado para " + role);
    }
  } finally {
    globalThis.fetch = original;
  }
});
Deno.test("admin inativo é negado", async () => {
  const original = globalThis.fetch;
  try {
    globalThis.fetch = async (input) =>
      new Response(
        JSON.stringify(
          String(input).endsWith("/auth/v1/user")
            ? { id: "u" }
            : [{ role: "admin", ativo: false }],
        ),
        { status: 200 },
      );
    const result = await handler(
      new Request("http://local", {
        method: "POST",
        headers: { Authorization: "Bearer teste" },
        body: "{}",
      }),
    );
    assert(result.status === 403, "admin desativado");
  } finally {
    globalThis.fetch = original;
  }
});
Deno.test("listagem não expõe metadados secretos de Auth", async () => {
  const original = globalThis.fetch;
  try {
    globalThis.fetch = async (input) => {
      const path = String(input);
      return new Response(
        JSON.stringify(
          path.endsWith("/auth/v1/user")
            ? { id: "u" }
            : path.includes("/admin/users")
            ? {
              users: [{
                id: "a",
                email: "a@example.com",
                encrypted_password: "segredo",
              }],
            }
            : path.includes("select=role")
            ? [{ role: "admin", ativo: true }]
            : [{ id: "a", nome: "A", role: "professor", ativo: true }],
        ),
        { status: 200 },
      );
    };
    const result = await handler(
      new Request("http://local", {
        method: "POST",
        headers: { Authorization: "Bearer teste" },
        body: JSON.stringify({ action: "list" }),
      }),
    );
    const data = await result.json();
    assert(
      result.status === 200 && !JSON.stringify(data).includes("segredo"),
      "resposta deve conter somente dados necessários",
    );
  } finally {
    globalThis.fetch = original;
  }
});
