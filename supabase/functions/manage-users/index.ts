// Operações privilegiadas ficam exclusivamente na Edge Function.
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const url = Deno.env.get("SUPABASE_URL")!;
const publicKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const response = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
async function api(
  path: string,
  body?: unknown,
  authorization = `Bearer ${serviceKey}`,
  method?: string,
) {
  const res = await fetch(url + path, {
    method: method ?? (body ? "POST" : "GET"),
    headers: {
      apikey: serviceKey,
      Authorization: authorization,
      "Content-Type": "application/json",
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  return {
    ok: res.ok,
    status: res.status,
    data: text ? JSON.parse(text) : null,
  };
}
export async function handler(req: Request) {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  if (req.method !== "POST") {
    return response({ error: "Método não permitido." }, 405);
  }
  try {
    const authorization = req.headers.get("Authorization") ?? "";
    if (!authorization.startsWith("Bearer ")) {
      return response({ error: "Entre na sua conta." }, 401);
    }
    const identity = await fetch(url + "/auth/v1/user", {
      headers: { apikey: publicKey, Authorization: authorization },
    });
    if (!identity.ok) return response({ error: "Sessão inválida." }, 401);
    const user = await identity.json();
    const profile = await api(
      `/rest/v1/profiles?id=eq.${
        encodeURIComponent(user.id)
      }&select=role,ativo`,
    );
    if (
      !profile.ok || profile.data?.[0]?.role !== "admin" ||
      !profile.data?.[0]?.ativo
    ) return response({ error: "Somente admin administra contas." }, 403);
    const body = await req.json();
    if (body.action === "list") {
      const page = Math.max(1, Math.trunc(Number(body.page) || 1));
      const users = await api(`/auth/v1/admin/users?page=${page}&per_page=50`);
      if (!users.ok) {
        return response({ error: "Falha ao consultar contas." }, 502);
      }
      const ids = users.data.users.map((u: { id: string }) => u.id);
      const profiles = ids.length
        ? await api(`/rest/v1/profiles?id=in.(${ids.join(",")})`)
        : { ok: true, data: [] };
      if (!profiles.ok) {
        return response({ error: "Falha ao consultar perfis." }, 502);
      }
      return response({
        users: users.data.users.map((u: { id: string; email: string }) => ({
          id: u.id,
          email: u.email,
          ...profiles.data.find((p: { id: string }) => p.id === u.id),
        })),
        has_more: users.data.users.length === 50,
      });
    }
    if (!["create", "update"].includes(body.action)) {
      return response({ error: "Ação inválida." }, 400);
    }
    const nome = typeof body.nome === "string" ? body.nome.trim() : "";
    if (
      !nome || nome.length > 150 ||
      !["professor", "gestor", "admin"].includes(body.role) ||
      typeof body.ativo !== "boolean"
    ) return response({ error: "Confira nome, papel e situação." }, 400);
    const email = typeof body.email === "string" ? body.email.trim() : "";
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return response({ error: "E-mail inválido." }, 400);
    }
    if (
      (body.action === "create" || body.password) &&
      (typeof body.password !== "string" || body.password.length < 8)
    ) {
      return response(
        { error: "A senha deve ter pelo menos 8 caracteres." },
        400,
      );
    }
    let id = body.id;
    if (body.action === "create") {
      const created = await api("/auth/v1/admin/users", {
        email,
        password: body.password,
        email_confirm: true,
        user_metadata: { nome },
      });
      if (!created.ok) {
        return response({
          error:
            "Não foi possível criar a conta. Verifique se o e-mail já está cadastrado.",
        }, 400);
      }
      id = created.data.id;
    } else if (typeof id !== "string" || !/^[0-9a-f-]{36}$/i.test(id)) {
      return response({ error: "Identificação inválida." }, 400);
    }
    const changed = await api("/rest/v1/rpc/admin_update_profile", {
      p_id: id,
      p_nome: nome,
      p_role: body.role,
      p_ativo: body.ativo,
    }, authorization);
    if (!changed.ok) {
      return response({
        error: body.action === "create"
          ? "Conta criada inativa. Atualize a lista e revise seu acesso antes de ativá-la."
          : changed.data?.code === "P0001"
          ? changed.data.message
          : "Não foi possível alterar o perfil.",
      }, 409);
    }
    if (body.action === "update") {
      const edited = await api(
        `/auth/v1/admin/users/${id}`,
        {
          email,
          ...(body.password ? { password: body.password } : {}),
          user_metadata: { nome },
          ban_duration: body.ativo ? "none" : "876000h",
        },
        undefined,
        "PUT",
      );
      if (!edited.ok) {
        return response({
          error:
            "Perfil atualizado, mas dados de login não foram atualizados. Reabra a conta e tente novamente.",
        }, 502);
      }
    }
    return response({ id, success: true });
  } catch (_) {
    return response(
      { error: "Não foi possível concluir. Tente novamente." },
      500,
    );
  }
}
export default { fetch: handler };
