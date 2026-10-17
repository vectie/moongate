// Local exported logs are read explicitly and never persisted by this page.
let transcriptSnapshot = null;
let transcriptGeneration = 0;
let transcriptSourceName = "Pasted transcript";
let transcriptMatchCursor = 0;

// Reader controls live beside the existing filter/download controls, not in a
// separate preview. Context never changes the filter or exported evidence.
function installTranscriptNavigation() {
  const count = $("transcript-count");
  if (!count || $("transcript-navigation")) return;
  if ($("transcript-json")) $("transcript-json").textContent = "Download matching JSON";
  if ($("transcript-markdown")) $("transcript-markdown").textContent = "Download matching Markdown";
  const bar = document.createElement("div");
  bar.id = "transcript-navigation";
  bar.className = "inline-actions transcript-navigation";
  const label = document.createElement("label");
  label.textContent = "Reading view ";
  const view = document.createElement("select");
  view.id = "transcript-context";
  for (const [value, title] of [["0", "Matching messages"], ["2", "Match with 2 nearby messages"], ["5", "Match with 5 nearby messages"]]) {
    const option = document.createElement("option");
    option.value = value;
    option.textContent = title;
    view.appendChild(option);
  }
  view.value = "0";
  view.addEventListener("change", renderTranscript);
  label.appendChild(view);
  bar.appendChild(label);
  for (const [id, title, step] of [["transcript-previous", "Previous match", -1], ["transcript-next", "Next match", 1]]) {
    const button = document.createElement("button");
    button.id = id;
    button.type = "button";
    button.className = "button-secondary";
    button.textContent = title;
    button.disabled = true;
    button.addEventListener("click", () => navigateTranscriptMatch(step));
    bar.appendChild(button);
  }
  const status = document.createElement("span");
  status.id = "transcript-navigation-status";
  status.setAttribute("aria-live", "polite");
  status.textContent = "Open a transcript to navigate matches.";
  bar.appendChild(status);
  count.parentNode.insertBefore(bar, count);
}

function transcriptMatchingIndices() {
  if (!transcriptSnapshot) return [];
  const query = ($("transcript-query")?.value || "").trim();
  const pattern = query ? transcriptQueryPattern(query) : null;
  const role = $("transcript-role")?.value || "";
  return transcriptSnapshot.messages.flatMap((message, index) =>
    (!role || message.role === role) && (!pattern || pattern.test(message.content)) ? [index] : []);
}

function navigateTranscriptMatch(step) {
  const matches = transcriptMatchingIndices();
  if (!matches.length) return;
  transcriptMatchCursor = Math.max(0, Math.min(matches.length - 1, transcriptMatchCursor + step));
  renderTranscript();
  const target = Array.from($("transcript-messages")?.children || []).find(node => node.dataset.sourceIndex === String(matches[transcriptMatchCursor]));
  target?.scrollIntoView?.({ block: "nearest" });
}

function resetTranscriptSearch() {
  transcriptMatchCursor = 0;
  renderTranscript();
}

function transcriptQueryPattern(query, global = false) {
  const escaped = query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return new RegExp(escaped, global ? "giu" : "iu");
}

// Literal DOM text only. Never interpret transcript text as markup or regex.
function appendTranscriptContent(element, content, query) {
  if (!query) { element.textContent = content; return; }
  // Work against original code-point offsets: lowercasing can change length.
  const pattern = transcriptQueryPattern(query, true);
  let start = 0;
  for (const match of content.matchAll(pattern)) {
    element.appendChild(document.createTextNode(content.slice(start, match.index)));
    const mark = document.createElement("mark");
    mark.textContent = match[0];
    element.appendChild(mark);
    start = match.index + match[0].length;
  }
  element.appendChild(document.createTextNode(content.slice(start)));
}

function transcriptInvalidate(message = "Source changed; open the transcript again.") {
  transcriptGeneration++;
  transcriptSnapshot = null;
  transcriptMatchCursor = 0;
  for (const id of ["transcript-previous", "transcript-next"]) if ($(id)) $(id).disabled = true;
  text("transcript-navigation-status", "Open a transcript to navigate matches.");
  const messages = $("transcript-messages");
  if (messages) messages.replaceChildren();
  for (const id of ["transcript-json", "transcript-markdown"]) if ($(id)) $(id).disabled = true;
  text("transcript-count", "");
  text("transcript-status", message);
}

function transcriptVisibleMessages() {
  if (!transcriptSnapshot) return [];
  return transcriptMatchingIndices().map(index => transcriptSnapshot.messages[index]);
}

function renderTranscript() {
  const container = $("transcript-messages");
  if (!container || !transcriptSnapshot) return;
  container.replaceChildren();
  const matches = transcriptMatchingIndices();
  transcriptMatchCursor = Math.max(0, Math.min(transcriptMatchCursor, matches.length - 1));
  const radius = [2, 5].includes(Number($("transcript-context")?.value)) ? Number($("transcript-context").value) : 0;
  const active = matches[transcriptMatchCursor];
  const indices = radius && matches.length
    ? Array.from({ length: Math.min(transcriptSnapshot.messages.length - 1, active + radius) - Math.max(0, active - radius) + 1 }, (_, offset) => Math.max(0, active - radius) + offset)
    : matches;
  const matching = new Set(matches);
  const query = ($("transcript-query")?.value || "").trim();
  for (const index of indices) {
    const message = transcriptSnapshot.messages[index];
    const article = document.createElement("article");
    article.className = "transcript-message" + (index === active ? " transcript-active-match" : "") + (!matching.has(index) ? " transcript-context-message" : "");
    article.dataset.sourceIndex = String(index);
    if (index === active) article.setAttribute("aria-current", "true");
    const header = document.createElement("strong");
    const date = message.ts == null ? null : new Date(message.ts);
    header.textContent = `#${index + 1} · ${message.role}` + (date && !Number.isNaN(date.valueOf()) ? ` · ${date.toISOString()}` : "") + (!matching.has(index) ? " · Nearby context (outside filter)" : index === active ? " · Current match" : " · Match");
    const content = document.createElement("pre");
    appendTranscriptContent(content, message.content, query);
    article.append(header, content);
    container.appendChild(article);
  }
  text("transcript-count", `${matches.length} of ${transcriptSnapshot.messages.length} messages match. ${indices.length} shown${radius ? " with nearby context" : ""}. Downloads include only matching messages, in source order; nearby context outside the filter is excluded.`);
  text("transcript-navigation-status", matches.length ? `Match ${transcriptMatchCursor + 1} of ${matches.length} · source message ${active + 1}` : "No matches. Change the text or speaker filter.");
  if ($("transcript-previous")) $("transcript-previous").disabled = !matches.length || transcriptMatchCursor === 0;
  if ($("transcript-next")) $("transcript-next").disabled = !matches.length || transcriptMatchCursor === matches.length - 1;
  for (const id of ["transcript-json", "transcript-markdown"]) $(id).disabled = matches.length === 0;
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
$("transcript-query")?.addEventListener("input", resetTranscriptSearch);
$("transcript-role")?.addEventListener("change", resetTranscriptSearch);
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

installTranscriptNavigation();
