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
Deno.test("professor não pode administrar usuários", async () => {
  const original = globalThis.fetch;
  try {
    for (const role of ["professor"]) {
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

Deno.test("gestor cria professor mas não cria nem altera admin", async () => {
  const original = globalThis.fetch;
  let writes = 0;
  try {
    globalThis.fetch = async (input, init) => {
      const path = String(input);
      if (init?.method === "POST" || init?.method === "PUT") writes++;
      const data = path.endsWith("/auth/v1/user")
        ? { id: "gestor" }
        : path.includes("id=eq.gestor")
        ? [{ role: "gestor", ativo: true }]
        : path.includes("/auth/v1/admin/users")
        ? { id: "11111111-1111-1111-1111-111111111111" }
        : path.includes("select=role")
        ? [{ role: "admin" }]
        : {};
      return new Response(JSON.stringify(data), { status: 200 });
    };
    const call = (data: unknown) =>
      handler(
        new Request("http://local", {
          method: "POST",
          headers: { Authorization: "Bearer test" },
          body: JSON.stringify(data),
        }),
      );
    const fields = {
      nome: "Professor",
      email: "p@example.com",
      password: "senha-teste-123",
      ativo: true,
    };
    assert(
      (await call({ ...fields, action: "create", role: "admin" })).status ===
        403,
      "gestor não cria admin",
    );
    assert(writes === 0, "nenhuma escrita ao tentar criar admin");
    assert(
      (await call({
        ...fields,
        action: "update",
        role: "professor",
        id: "22222222-2222-2222-2222-222222222222",
      })).status === 403,
      "admin protegido mesmo com papel de destino professor",
    );
    assert(writes === 0, "nenhuma alteração de Auth ou perfil do admin");
    assert(
      (await call({ ...fields, action: "create", role: "professor" }))
        .status === 200,
      "gestor cria professor",
    );
    assert(writes === 2, "criação Auth e ativação de perfil");
  } finally {
    globalThis.fetch = original;
  }
});
