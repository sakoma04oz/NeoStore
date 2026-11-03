const ALLOWED_ORIGIN = "https://sakoma04oz.github.io";

export default {
  async fetch(request, env) {
    const origin = request.headers.get("Origin") || "";
    const cors = {
      "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
      "Vary": "Origin"
    };

    if (origin !== ALLOWED_ORIGIN) return new Response("Origin not allowed", { status: 403 });
    if (request.method === "OPTIONS") return new Response(null, { headers: cors });
    if (request.method !== "POST") return new Response("Method not allowed", { status: 405, headers: cors });

    try {
      if (!env.OPENAI_API_KEY) throw new Error("Server is missing its API key");
      const body = await request.json();
      const messages = Array.isArray(body.messages) ? body.messages : [];
      const safeMessages = messages
        .filter(m => m && ["user", "assistant"].includes(m.role) && typeof m.content === "string")
        .slice(-12)
        .map(m => ({ role: m.role, content: m.content.slice(0, 4000) }));

      if (!safeMessages.length || !safeMessages.some(m => m.role === "user")) {
        return Response.json({ error: "اكتب سؤالك أولاً." }, { status: 400, headers: cors });
      }

      const upstream = await fetch("https://api.openai.com/v1/responses", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${env.OPENAI_API_KEY}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          model: "gpt-6-luna",
          instructions: "You are NeoAI, a helpful multilingual assistant. Reply in the language used by the user. Be clear, accurate, age-appropriate, and acknowledge uncertainty.",
          input: safeMessages,
          max_output_tokens: 900
        })
      });

      const data = await upstream.json();
      if (!upstream.ok) {
        return Response.json({ error: "تعذر الحصول على إجابة من خدمة الذكاء الاصطناعي." }, { status: 502, headers: cors });
      }

      const answer = (data.output || [])
        .flatMap(item => item.content || [])
        .filter(part => part.type === "output_text")
        .map(part => part.text)
        .join("\n")
        .trim();

      if (!answer) throw new Error("Empty model response");
      return Response.json({ answer }, { headers: cors });
    } catch (error) {
      return Response.json({ error: "حدث خطأ في الخادم. حاول مرة أخرى لاحقاً." }, { status: 500, headers: cors });
    }
  }
};
