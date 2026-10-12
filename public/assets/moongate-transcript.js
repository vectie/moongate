// Local exported logs are read explicitly and never persisted by this page.
let transcriptSnapshot = null;
let transcriptGeneration = 0;
let transcriptSourceName = "Pasted transcript";

function transcriptInvalidate(message = "Source changed; open the transcript again.") {
  transcriptGeneration++;
  transcriptSnapshot = null;
  const messages = $("transcript-messages");
  if (messages) messages.replaceChildren();
  for (const id of ["transcript-json", "transcript-markdown"]) if ($(id)) $(id).disabled = true;
  text("transcript-count", "");
  text("transcript-status", message);
}

function transcriptVisibleMessages() {
  if (!transcriptSnapshot) return [];
  const query = ($("transcript-query")?.value || "").trim().toLocaleLowerCase();
  const role = $("transcript-role")?.value || "";
  return transcriptSnapshot.messages.filter(message =>
    (!role || message.role === role) && (!query || message.content.toLocaleLowerCase().includes(query)));
}

function renderTranscript() {
  const container = $("transcript-messages");
  if (!container || !transcriptSnapshot) return;
  container.replaceChildren();
  const visible = transcriptVisibleMessages();
  for (const message of visible) {
    const article = document.createElement("article");
    article.className = "transcript-message";
    const header = document.createElement("strong");
    const date = message.ts == null ? null : new Date(message.ts);
    header.textContent = message.role + (date && !Number.isNaN(date.valueOf()) ? ` · ${date.toISOString()}` : "");
    const content = document.createElement("pre");
    content.textContent = message.content;
    article.append(header, content);
    container.appendChild(article);
  }
  text("transcript-count", `${visible.length} of ${transcriptSnapshot.messages.length} messages shown. Downloads include only these visible messages, in source order.`);
  for (const id of ["transcript-json", "transcript-markdown"]) $(id).disabled = visible.length === 0;
}

async function openTranscript() {
  transcriptInvalidate("Opening transcript…");
  const generation = transcriptGeneration;
  const content = $("transcript-content")?.value || "";
  const format = $("transcript-format")?.value || "auto";
  try {
    if (new TextEncoder().encode(content).length > 4 * 1024 * 1024) throw new Error("Transcript exceeds the 4 MiB limit.");
    const result = await postJson(endpoints.transcriptPreview, { content, format, sourceName: transcriptSourceName });
    if (generation !== transcriptGeneration) return;
    if (result?.schema !== "moongate.transcript.v1" || !Array.isArray(result.messages) || !result.messages.every(message => typeof message.role === "string" && typeof message.content === "string")) throw new Error("The gateway returned an unreadable transcript.");
    transcriptSnapshot = result;
    const role = $("transcript-role");
    role.replaceChildren();
    for (const value of ["", ...new Set(result.messages.map(message => message.role))]) {
      const option = document.createElement("option");
      option.value = value;
      option.textContent = value || "All speakers";
      role.appendChild(option);
    }
    role.value = "";
    $("transcript-query").value = "";
    text("transcript-status", `${result.sourceName} · ${result.format} · ${result.messageCount} readable messages. ${result.skippedRecords} metadata or unsupported records omitted. Text and tool summaries only; original files are unchanged.`);
    renderTranscript();
  } catch (error) {
    if (generation === transcriptGeneration) transcriptInvalidate(error.message || String(error));
  }
}

async function loadTranscriptFile(file) {
  if (!file) return;
  transcriptInvalidate("Reading selected file…");
  const generation = transcriptGeneration;
  $("transcript-content").value = "";
  try {
    if (file.size > 4 * 1024 * 1024) throw new Error("Transcript exceeds the 4 MiB limit.");
    const content = await file.text();
    if (generation !== transcriptGeneration) return;
    $("transcript-content").value = content;
    transcriptSourceName = file.name;
    text("transcript-status", `${file.name} is ready. Choose Open transcript to parse it.`);
  } catch (error) {
    if (generation === transcriptGeneration) transcriptInvalidate(error.message || String(error));
  }
}

function transcriptExport(format) {
  const messages = transcriptVisibleMessages();
  if (!transcriptSnapshot || !messages.length) return null;
  const source = transcriptSnapshot.sourceName;
  if (format === "json") return {
    mime: "application/json;charset=utf-8", extension: "json",
    content: JSON.stringify({
      schema: "moongate.transcript.v1", sourceName: source, format: transcriptSnapshot.format,
      messageCount: messages.length, sourceMessageCount: transcriptSnapshot.messages.length,
      filter: { text: $("transcript-query").value.trim(), role: $("transcript-role").value }, messages,
    }, null, 2) + "\n",
  };
  const label = source.replace(/[\r\n]/g, " ");
  return {
    mime: "text/markdown;charset=utf-8", extension: "md",
    content: `# Conversation transcript\n\nSource: ${label}\nFormat: ${transcriptSnapshot.format}\nMessages: ${messages.length} of ${transcriptSnapshot.messages.length}\n\n` + messages.map(message => {
      const date = message.ts == null ? null : new Date(message.ts);
      const timestamp = date && !Number.isNaN(date.valueOf()) ? ` (${date.toISOString()})` : "";
      return `## ${message.role.replace(/[\r\n]/g, " ")}${timestamp}\n\n${message.content}\n`;
    }).join("\n"),
  };
}

function downloadTranscript(format) {
  const output = transcriptExport(format);
  if (!output) return;
  const url = URL.createObjectURL(new Blob([output.content], { type: output.mime }));
  const link = document.createElement("a");
  link.href = url;
  link.download = `moongate-transcript.${output.extension}`;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

$("transcript-form")?.addEventListener("submit", event => { event.preventDefault(); openTranscript(); });
$("transcript-file")?.addEventListener("change", event => { loadTranscriptFile(event.target.files?.[0]); });
$("transcript-content")?.addEventListener("input", () => {
  transcriptSourceName = "Pasted transcript";
  $("transcript-file").value = "";
  transcriptInvalidate();
});
$("transcript-format")?.addEventListener("change", () => transcriptInvalidate());
$("transcript-query")?.addEventListener("input", renderTranscript);
$("transcript-role")?.addEventListener("change", renderTranscript);
$("transcript-json")?.addEventListener("click", () => downloadTranscript("json"));
$("transcript-markdown")?.addEventListener("click", () => downloadTranscript("markdown"));
$("transcript-clear")?.addEventListener("click", () => {
  $("transcript-form").reset();
  $("transcript-query").value = "";
  $("transcript-role").value = "";
  transcriptSourceName = "Pasted transcript";
  transcriptInvalidate("No transcript open.");
});
$("transcript-sample")?.addEventListener("click", () => {
  transcriptInvalidate("Sample ready. Choose Open transcript.");
  transcriptSourceName = "Sample conversation";
  $("transcript-file").value = "";
  $("transcript-format").value = "auto";
  $("transcript-content").value = JSON.stringify([
    { role: "user", content: "How can I preserve this conversation?" },
    { role: "assistant", content: "Download it as JSON to reopen later, or Markdown to keep with your project notes." },
    { role: "user", content: "Find the message about Markdown." },
  ], null, 2);
});
