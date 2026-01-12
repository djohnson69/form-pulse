import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method Not Allowed", {
      status: 405,
      headers: corsHeaders,
    });
  }

  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) {
    return jsonResponse({ error: "OPENAI_API_KEY is missing." }, 500);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch (_e) {
    return jsonResponse({ error: "Invalid JSON payload." }, 400);
  }

  const type = (payload.type ?? "summary").toString();
  const inputText = (payload.inputText ?? "").toString();
  const imageBase64 = payload.imageBase64?.toString();
  const audioBase64 = payload.audioBase64?.toString();
  const audioMimeType = payload.audioMimeType?.toString();
  const targetLanguage = payload.targetLanguage?.toString();
  const checklistCount = Number(payload.checklistCount ?? 8);

  if (!inputText && !imageBase64 && !audioBase64) {
    return jsonResponse(
      { error: "Provide inputText, imageBase64, or audioBase64." },
      400,
    );
  }

  const model = Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini";
  const baseUrl =
    (Deno.env.get("OPENAI_BASE_URL") ?? "https://api.openai.com/v1").replace(
      /\/+$/,
      "",
    );
  const organization = Deno.env.get("OPENAI_ORG");

  let transcript: string | null = null;
  if (audioBase64) {
    try {
      transcript = await transcribeAudio({
        audioBase64,
        audioMimeType,
        apiKey,
        baseUrl,
        organization,
      });
    } catch (error) {
      return jsonResponse(
        { error: `Audio transcription failed: ${error}` },
        500,
      );
    }
  }

  const combinedInput = buildCombinedInput(inputText, transcript);

  const messages = buildMessages({
    type,
    inputText: combinedInput,
    imageBase64,
    targetLanguage,
    checklistCount,
  });

  try {
    const response = await fetch(`${baseUrl}/chat/completions`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        ...(organization ? { "OpenAI-Organization": organization } : {}),
      },
      body: JSON.stringify({
        model,
        messages,
        temperature: 0.2,
      }),
    });

    if (!response.ok) {
      const text = await response.text();
      return jsonResponse(
        { error: `OpenAI request failed (${response.status}): ${text}` },
        500,
      );
    }

    const data = await response.json();
    const outputText =
      data?.choices?.[0]?.message?.content?.toString() ?? "";

    return jsonResponse({ outputText, model, type, transcript });
  } catch (error) {
    return jsonResponse({ error: `${error}` }, 500);
  }
});

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function buildMessages({
  type,
  inputText,
  imageBase64,
  targetLanguage,
  checklistCount,
}: {
  type: string;
  inputText: string;
  imageBase64?: string;
  targetLanguage?: string;
  checklistCount: number;
}) {
  const imageUrl = imageBase64
    ? imageBase64.startsWith("data:")
      ? imageBase64
      : `data:image/jpeg;base64,${imageBase64}`
    : null;

  switch (type) {
    case "photo_caption":
      return [
        {
          role: "system",
          content:
            "Write a short photo caption. Output text only. Keep it concise.",
        },
        {
          role: "user",
          content: [
            { type: "text", text: inputText || "Caption this image." },
            ...(imageUrl ? [{ type: "image_url", image_url: { url: imageUrl } }] : []),
          ],
        },
      ];
    case "progress_recap":
      return [
        {
          role: "system",
          content:
            "Create a concise progress recap with accomplishments, blockers, and next steps.",
        },
        { role: "user", content: inputText },
      ];
    case "translation":
      return [
        {
          role: "system",
          content:
            "Translate text. Output only the translation in the target language.",
        },
        {
          role: "user",
          content: `Target language: ${targetLanguage ?? "Spanish"}\nText: ${inputText}`,
        },
      ];
    case "checklist_builder":
      return [
        {
          role: "system",
          content:
            "Return a short checklist. Output as bullet points, one per line.",
        },
        {
          role: "user",
          content: `Create ${checklistCount} checklist items for: ${inputText}`,
        },
      ];
    case "field_report":
      return [
        {
          role: "system",
          content:
            "Generate a professional field report with sections: Summary, Findings, Actions, Risks.",
        },
        {
          role: "user",
          content: [
            { type: "text", text: `Notes: ${inputText}` },
            ...(imageUrl ? [{ type: "image_url", image_url: { url: imageUrl } }] : []),
          ],
        },
      ];
    case "walkthrough_notes":
      return [
        {
          role: "system",
          content:
            "Generate walkthrough notes with observations and recommended actions.",
        },
        {
          role: "user",
          content: [
            { type: "text", text: inputText },
            ...(imageUrl ? [{ type: "image_url", image_url: { url: imageUrl } }] : []),
          ],
        },
      ];
    case "daily_log":
      return [
        {
          role: "system",
          content:
            "Write a structured daily log with sections: Work completed, Issues, Safety, Tomorrow.",
        },
        { role: "user", content: inputText },
      ];
    case "assistant":
      return [
        {
          role: "system",
          content:
            "You are Form Bridge AI assistant for enterprise operations teams. Use only the provided context to answer. If data is missing, say so and ask a clarifying question. Provide concise, actionable answers. When listing records, include name, status, and due date if available. Keep responses under 10 bullets.",
        },
        { role: "user", content: inputText },
      ];
    case "summary":
    default:
      return [
        {
          role: "system",
          content:
            "Summarize field notes. Output plain text only, keep it actionable and under 120 words.",
        },
        { role: "user", content: inputText },
      ];
  }
}

function buildCombinedInput(inputText: string, transcript: string | null) {
  const parts = [];
  if (inputText && inputText.trim().length > 0) {
    parts.push(inputText.trim());
  }
  if (transcript && transcript.trim().length > 0) {
    parts.push(transcript.trim());
  }
  return parts.join("\n");
}

async function transcribeAudio({
  audioBase64,
  audioMimeType,
  apiKey,
  baseUrl,
  organization,
}: {
  audioBase64: string;
  audioMimeType?: string;
  apiKey: string;
  baseUrl: string;
  organization?: string | null;
}) {
  const cleaned = stripDataUrl(audioBase64);
  const audioBytes = decodeBase64(cleaned);
  if (!audioBytes || audioBytes.length === 0) return null;

  const model = Deno.env.get("OPENAI_TRANSCRIBE_MODEL") ?? "whisper-1";
  const mimeType = audioMimeType ?? "audio/m4a";
  const filename = guessAudioFilename(mimeType);
  const formData = new FormData();
  formData.append("file", new Blob([audioBytes], { type: mimeType }), filename);
  formData.append("model", model);

  const response = await fetch(`${baseUrl}/audio/transcriptions`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      ...(organization ? { "OpenAI-Organization": organization } : {}),
    },
    body: formData,
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(
      `OpenAI transcription failed (${response.status}): ${text}`,
    );
  }

  const data = await response.json();
  return data?.text?.toString() ?? null;
}

function stripDataUrl(value: string) {
  const marker = "base64,";
  const idx = value.indexOf(marker);
  if (idx === -1) return value;
  return value.slice(idx + marker.length);
}

function decodeBase64(value: string) {
  try {
    const binary = atob(value);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes;
  } catch (_) {
    return null;
  }
}

function guessAudioFilename(mimeType: string) {
  if (mimeType.includes("wav")) return "audio.wav";
  if (mimeType.includes("mpeg")) return "audio.mp3";
  if (mimeType.includes("ogg")) return "audio.ogg";
  return "audio.m4a";
}
