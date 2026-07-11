///|
fn moon_provider_preset_summary_catalog() -> Array[Json] {
  [
    moon_provider_preset_summary_json(
      "claude", "Claude Official", "", "https://www.anthropic.com/claude-code", "",
      "official", true, false, "", "anthropic",
    ),
    moon_provider_preset_summary_json(
      "claude", "Shengsuanyun", "providerForm.presets.shengsuanyun", "https://www.shengsuanyun.com/?from=CH_4HHXMRYF",
      "https://www.shengsuanyun.com/?from=CH_4HHXMRYF", "aggregator", false, true,
      "shengsuanyun", "shengsuanyun",
    ),
    moon_provider_preset_summary_json(
      "claude", "PatewayAI", "", "https://pateway.ai", "https://pateway.ai/?ch=etzpm8&aff=WB6M6F67#/",
      "third_party", false, true, "patewayai", "pateway",
    ),
    moon_provider_preset_summary_json(
      "claude", "火山Agentplan", "", "https://www.volcengine.com/activity/agentplan?utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "https://www.volcengine.com/activity/agentplan?utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "cn_official", false, true, "volcengine_agentplan", "huoshan",
    ),
    moon_provider_preset_summary_json(
      "claude", "BytePlus", "", "https://www.byteplus.com/en/product/modelark?utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "https://www.byteplus.com/en/product/modelark?utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "cn_official", false, true, "byteplus", "byteplus",
    ),
    moon_provider_preset_summary_json(
      "claude", "DouBaoSeed", "", "https://console.volcengine.com/ark/region:ark+cn-beijing/apiKey?apikey=%7B%7D&utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "https://console.volcengine.com/ark/region:ark+cn-beijing/apiKey?apikey=%7B%7D&utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "cn_official", false, true, "doubaoseed", "doubao",
    ),
    moon_provider_preset_summary_json(
      "claude", "CCSub", "", "https://www.ccsub.net", "https://www.ccsub.net/register?ref=Y6Z8DXEA",
      "aggregator", false, true, "ccsub", "ccsub",
    ),
    moon_provider_preset_summary_json(
      "claude", "Gemini Native", "", "https://ai.google.dev/gemini-api", "https://aistudio.google.com/app/apikey",
      "third_party", false, false, "", "gemini",
    ),
    moon_provider_preset_summary_json(
      "claude", "DeepSeek", "", "https://platform.deepseek.com", "", "cn_official",
      false, false, "", "deepseek",
    ),
    moon_provider_preset_summary_json(
      "claude", "OpenCode Go", "", "https://opencode.ai", "", "third_party", false,
      false, "", "opencode",
    ),
    moon_provider_preset_summary_json(
      "claude", "Zhipu GLM", "", "https://open.bigmodel.cn", "https://www.bigmodel.cn/claude-code?ic=RRVJPB5SII",
      "cn_official", false, false, "", "zhipu",
    ),
    moon_provider_preset_summary_json(
      "claude", "Zhipu GLM en", "", "https://z.ai", "https://z.ai/subscribe?ic=8JVLJQFSKB",
      "cn_official", false, false, "", "zhipu",
    ),
    moon_provider_preset_summary_json(
      "claude", "Baidu Qianfan Coding Plan", "", "https://cloud.baidu.com/product/qianfan_modelbuilder",
      "https://console.bce.baidu.com/qianfan/ais/console/applicationConsole/application",
      "cn_official", false, false, "", "baidu",
    ),
    moon_provider_preset_summary_json(
      "claude", "Bailian", "", "https://bailian.console.aliyun.com", "", "cn_official",
      false, false, "", "bailian",
    ),
    moon_provider_preset_summary_json(
      "claude", "Bailian For Coding", "", "https://bailian.console.aliyun.com", "",
      "cn_official", false, false, "", "bailian",
    ),
    moon_provider_preset_summary_json(
      "claude", "Kimi", "", "https://platform.moonshot.cn/console?aff=moongate",
      "", "cn_official", false, false, "", "kimi",
    ),
    moon_provider_preset_summary_json(
      "claude", "Kimi For Coding", "", "https://www.kimi.com/code/docs/?aff=moongate",
      "", "cn_official", false, false, "", "kimi",
    ),
    moon_provider_preset_summary_json(
      "claude", "StepFun", "", "https://platform.stepfun.com/step-plan", "https://platform.stepfun.com/interface-key",
      "cn_official", false, false, "", "stepfun",
    ),
    moon_provider_preset_summary_json(
      "claude", "StepFun en", "", "https://platform.stepfun.ai/step-plan", "https://platform.stepfun.ai/interface-key",
      "cn_official", false, false, "", "stepfun",
    ),
    moon_provider_preset_summary_json(
      "claude", "ModelScope", "", "https://modelscope.cn", "", "aggregator", false,
      false, "", "modelscope",
    ),
    moon_provider_preset_summary_json(
      "claude", "KAT-Coder", "", "https://console.streamlake.ai", "https://console.streamlake.ai/console/api-key",
      "cn_official", false, false, "", "catcoder",
    ),
    moon_provider_preset_summary_json(
      "claude", "Longcat", "", "https://longcat.chat/platform", "https://longcat.chat/platform/api_keys",
      "cn_official", false, false, "", "longcat",
    ),
    moon_provider_preset_summary_json(
      "claude", "MiniMax", "", "https://platform.minimaxi.com", "https://platform.minimaxi.com/subscribe/coding-plan",
      "cn_official", false, true, "minimax_cn", "minimax",
    ),
    moon_provider_preset_summary_json(
      "claude", "MiniMax en", "", "https://platform.minimax.io", "https://platform.minimax.io/subscribe/coding-plan",
      "cn_official", false, true, "minimax_en", "minimax",
    ),
    moon_provider_preset_summary_json(
      "claude", "BaiLing", "", "https://alipaytbox.yuque.com/sxs0ba/ling/get_started",
      "", "cn_official", false, false, "", "",
    ),
    moon_provider_preset_summary_json(
      "claude", "AiHubMix", "", "https://aihubmix.com", "https://aihubmix.com", "aggregator",
      false, false, "", "aihubmix",
    ),
    moon_provider_preset_summary_json(
      "claude", "CherryIN", "", "https://open.cherryin.ai", "https://open.cherryin.ai/console/token",
      "aggregator", false, false, "", "cherryin",
    ),
    moon_provider_preset_summary_json(
      "claude", "SiliconFlow", "", "https://siliconflow.cn", "https://cloud.siliconflow.cn/i/drGuwc9k",
      "aggregator", false, true, "siliconflow", "siliconflow",
    ),
    moon_provider_preset_summary_json(
      "claude", "SiliconFlow en", "", "https://siliconflow.com", "https://cloud.siliconflow.cn/i/drGuwc9k",
      "aggregator", false, true, "siliconflow", "siliconflow",
    ),
    moon_provider_preset_summary_json(
      "claude", "DMXAPI", "", "https://www.dmxapi.cn", "https://www.dmxapi.cn", "aggregator",
      false, true, "dmxapi", "",
    ),
    moon_provider_preset_summary_json(
      "claude", "PackyCode", "", "https://www.packyapi.com", "https://www.packyapi.com/register?aff=moongate",
      "third_party", false, true, "packycode", "packycode",
    ),
    moon_provider_preset_summary_json(
      "claude", "APIKEY.FUN", "", "https://apikey.fun", "https://apikey.fun", "third_party",
      false, true, "apikeyfun", "apikeyfun",
    ),
    moon_provider_preset_summary_json(
      "claude", "APINebula", "", "https://apinebula.com", "https://apinebula.com/02rw5X",
      "third_party", false, true, "apinebula", "apinebula",
    ),
    moon_provider_preset_summary_json(
      "claude", "AtlasCloud", "", "https://www.atlascloud.ai/console/coding-plan",
      "https://www.atlascloud.ai/console/coding-plan", "aggregator", false, true,
      "atlascloud", "atlascloud",
    ),
    moon_provider_preset_summary_json(
      "claude", "SudoCode", "", "https://sudocode.us", "https://sudocode.us", "third_party",
      false, true, "sudocode", "sudocode",
    ),
    moon_provider_preset_summary_json(
      "claude", "ClaudeAPI", "", "https://claudeapi.com", "https://console.claudeapi.com/register?aff=pCLD",
      "aggregator", false, true, "claudeapi", "claudeapi",
    ),
    moon_provider_preset_summary_json(
      "claude", "ClaudeCN", "", "https://claudecn.top", "https://claudecn.top/register?aff=moongate",
      "third_party", false, true, "claudecn", "claudecn",
    ),
    moon_provider_preset_summary_json(
      "claude", "RunAPI", "", "https://runapi.co", "https://runapi.co", "aggregator",
      false, true, "runapi", "runapi",
    ),
    moon_provider_preset_summary_json(
      "claude", "RelaxyCode", "", "https://www.relaxycode.com", "https://www.relaxycode.com/register",
      "third_party", false, false, "", "relaxcode",
    ),
    moon_provider_preset_summary_json(
      "claude", "Cubence", "", "https://cubence.com", "https://cubence.com/signup?code=MOONGATE&source=moongate",
      "third_party", false, true, "cubence", "cubence",
    ),
    moon_provider_preset_summary_json(
      "claude", "AIGoCode", "", "https://aigocode.com", "https://aigocode.com", "third_party",
      false, true, "aigocode", "aigocode",
    ),
    moon_provider_preset_summary_json(
      "claude", "RightCode", "", "https://www.right.codes", "https://www.right.codes/register?aff=MOONGATE",
      "third_party", false, true, "rightcode", "rc",
    ),
    moon_provider_preset_summary_json(
      "claude", "AICodeMirror", "", "https://www.aicodemirror.com", "https://www.aicodemirror.com/register?invitecode=9915W3",
      "third_party", false, true, "aicodemirror", "aicodemirror",
    ),
    moon_provider_preset_summary_json(
      "claude", "CrazyRouter", "", "https://www.crazyrouter.com", "https://www.crazyrouter.com/register?aff=OZcm&ref=moongate",
      "third_party", false, true, "crazyrouter", "crazyrouter",
    ),
    moon_provider_preset_summary_json(
      "claude", "SSSAiCode", "", "https://sssaicodeapi.com", "https://sssaicodeapi.com/register?ref=DCP0SM",
      "third_party", false, true, "sssaicode", "sssaicode",
    ),
    moon_provider_preset_summary_json(
      "claude", "Compshare", "providerForm.presets.ucloud", "https://www.compshare.cn",
      "https://www.compshare.cn/coding-plan?ytag=GPU_YY_YX_git_moongate", "aggregator",
      false, true, "ucloud", "ucloud",
    ),
    moon_provider_preset_summary_json(
      "claude", "Compshare Coding Plan", "providerForm.presets.ucloudCoding", "https://www.compshare.cn",
      "https://www.compshare.cn/coding-plan?ytag=GPU_YY_YX_git_moongate", "aggregator",
      false, true, "ucloud", "ucloud",
    ),
    moon_provider_preset_summary_json(
      "claude", "Micu", "", "https://www.micuapi.ai", "https://www.micuapi.ai/register?aff=aOYQ",
      "third_party", false, true, "micu", "micu",
    ),
    moon_provider_preset_summary_json(
      "claude", "CTok.ai", "", "https://ctok.ai", "https://ctok.ai", "third_party",
      false, true, "ctok", "ctok",
    ),
    moon_provider_preset_summary_json(
      "claude", "E-FlowCode", "", "https://e-flowcode.cc", "https://e-flowcode.cc",
      "third_party", false, false, "", "eflowcode",
    ),
    moon_provider_preset_summary_json(
      "claude", "OpenRouter", "", "https://openrouter.ai", "https://openrouter.ai/keys",
      "aggregator", false, false, "", "openrouter",
    ),
    moon_provider_preset_summary_json(
      "claude", "TheRouter", "", "https://therouter.ai", "https://dashboard.therouter.ai",
      "aggregator", false, false, "", "",
    ),
    moon_provider_preset_summary_json(
      "claude", "Novita AI", "", "https://novita.ai", "https://novita.ai", "aggregator",
      false, false, "", "novita",
    ),
    moon_provider_preset_summary_json(
      "claude", "GitHub Copilot", "", "https://github.com/features/copilot", "",
      "third_party", false, false, "", "github",
    ),
    moon_provider_preset_summary_json(
      "claude", "Codex", "", "https://openai.com/chatgpt/pricing", "", "third_party",
      false, false, "", "openai",
    ),
    moon_provider_preset_summary_json(
      "claude", "LemonData", "", "https://lemondata.cc", "https://lemondata.cc/r/FFX1ZDUP",
      "third_party", false, true, "lemondata", "lemondata",
    ),
    moon_provider_preset_summary_json(
      "claude", "Nvidia", "", "https://build.nvidia.com", "https://build.nvidia.com/settings/api-keys",
      "aggregator", false, false, "", "nvidia",
    ),
    moon_provider_preset_summary_json(
      "claude", "PIPELLM", "", "https://code.pipellm.ai", "https://code.pipellm.ai/login?ref=uvw650za",
      "aggregator", false, false, "", "pipellm",
    ),
    moon_provider_preset_summary_json(
      "claude", "Xiaomi MiMo", "", "https://platform.xiaomimimo.com", "https://platform.xiaomimimo.com/#/console/api-keys",
      "cn_official", false, false, "", "xiaomimimo",
    ),
    moon_provider_preset_summary_json(
      "claude", "Xiaomi MiMo Token Plan (China)", "", "https://platform.xiaomimimo.com/#/token-plan",
      "https://platform.xiaomimimo.com/#/console/plan-manage", "cn_official", false,
      false, "", "xiaomimimo",
    ),
    moon_provider_preset_summary_json(
      "claude", "AWS Bedrock (AKSK)", "", "https://aws.amazon.com/bedrock/", "",
      "cloud_provider", false, false, "", "aws",
    ),
    moon_provider_preset_summary_json(
      "claude", "AWS Bedrock (API Key)", "", "https://aws.amazon.com/bedrock/", "",
      "cloud_provider", false, false, "", "aws",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "Claude Desktop Official", "", "https://claude.ai/download",
      "", "official", false, false, "", "anthropic",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "Shengsuanyun", "providerForm.presets.shengsuanyun", "https://www.shengsuanyun.com/?from=CH_4HHXMRYF",
      "https://www.shengsuanyun.com/?from=CH_4HHXMRYF", "aggregator", false, true,
      "shengsuanyun", "shengsuanyun",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "PatewayAI", "", "https://pateway.ai", "https://pateway.ai/?ch=etzpm8&aff=WB6M6F67#/",
      "third_party", false, true, "patewayai", "pateway",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "火山Agentplan", "", "https://www.volcengine.com/activity/agentplan?utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "https://www.volcengine.com/activity/agentplan?utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "cn_official", false, true, "volcengine_agentplan", "huoshan",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "BytePlus", "", "https://www.byteplus.com/en/product/modelark?utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "https://www.byteplus.com/en/product/modelark?utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "cn_official", false, true, "byteplus", "byteplus",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "DouBaoSeed", "", "https://console.volcengine.com/ark/region:ark+cn-beijing/apiKey?apikey=%7B%7D&utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "https://console.volcengine.com/ark/region:ark+cn-beijing/apiKey?apikey=%7B%7D&utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "cn_official", false, true, "doubaoseed", "doubao",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "CCSub", "", "https://www.ccsub.net", "https://www.ccsub.net/register?ref=Y6Z8DXEA",
      "aggregator", false, true, "ccsub", "ccsub",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "Gemini Native", "", "https://ai.google.dev/gemini-api",
      "https://aistudio.google.com/app/apikey", "third_party", false, false, "",
      "gemini",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "GitHub Copilot", "", "https://github.com/features/copilot",
      "", "third_party", false, false, "", "github",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "Codex", "", "https://openai.com/chatgpt/pricing", "", "third_party",
      false, false, "", "openai",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "DeepSeek", "", "https://platform.deepseek.com", "", "cn_official",
      false, false, "", "deepseek",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "OpenCode Go", "", "https://opencode.ai", "", "third_party",
      false, false, "", "opencode",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "Zhipu GLM", "", "https://open.bigmodel.cn", "https://www.bigmodel.cn/claude-code?ic=RRVJPB5SII",
      "cn_official", false, false, "", "zhipu",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "Zhipu GLM en", "", "https://z.ai", "https://z.ai/subscribe?ic=8JVLJQFSKB",
      "cn_official", false, false, "", "zhipu",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "Baidu Qianfan Coding Plan", "", "https://cloud.baidu.com/product/qianfan_modelbuilder",
      "https://console.bce.baidu.com/qianfan/ais/console/applicationConsole/application",
      "cn_official", false, false, "", "baidu",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "Bailian", "", "https://bailian.console.aliyun.com", "",
      "cn_official", false, false, "", "bailian",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "Bailian For Coding", "", "https://bailian.console.aliyun.com",
      "", "cn_official", false, false, "", "bailian",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "Kimi", "", "https://platform.moonshot.cn/console?aff=moongate",
      "", "cn_official", false, false, "", "kimi",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "Kimi For Coding", "", "https://www.kimi.com/code/docs/?aff=moongate",
      "", "cn_official", false, false, "", "kimi",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "StepFun", "", "https://platform.stepfun.com/step-plan",
      "https://platform.stepfun.com/interface-key", "cn_official", false, false,
      "", "stepfun",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "StepFun en", "", "https://platform.stepfun.ai/step-plan",
      "https://platform.stepfun.ai/interface-key", "cn_official", false, false, "",
      "stepfun",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "ModelScope", "", "https://modelscope.cn", "", "aggregator",
      false, false, "", "modelscope",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "Longcat", "", "https://longcat.chat/platform", "https://longcat.chat/platform/api_keys",
      "cn_official", false, false, "", "longcat",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "MiniMax", "", "https://platform.minimaxi.com", "https://platform.minimaxi.com/subscribe/coding-plan",
      "cn_official", false, true, "minimax_cn", "minimax",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "MiniMax en", "", "https://platform.minimax.io", "https://platform.minimax.io/subscribe/coding-plan",
      "cn_official", false, true, "minimax_en", "minimax",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "BaiLing", "", "https://alipaytbox.yuque.com/sxs0ba/ling/get_started",
      "", "cn_official", false, false, "", "",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "AiHubMix", "", "https://aihubmix.com", "https://aihubmix.com",
      "aggregator", false, false, "", "aihubmix",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "CherryIN", "", "https://open.cherryin.ai", "https://open.cherryin.ai/console/token",
      "aggregator", false, false, "", "cherryin",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "SiliconFlow", "", "https://siliconflow.cn", "https://cloud.siliconflow.cn/i/drGuwc9k",
      "aggregator", false, true, "siliconflow", "siliconflow",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "SiliconFlow en", "", "https://siliconflow.com", "https://cloud.siliconflow.cn/i/drGuwc9k",
      "aggregator", false, true, "siliconflow", "siliconflow",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "DMXAPI", "", "https://www.dmxapi.cn", "https://www.dmxapi.cn",
      "aggregator", false, true, "dmxapi", "",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "PackyCode", "", "https://www.packyapi.com", "https://www.packyapi.com/register?aff=moongate",
      "third_party", false, true, "packycode", "packycode",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "APIKEY.FUN", "", "https://apikey.fun", "https://apikey.fun",
      "third_party", false, true, "apikeyfun", "apikeyfun",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "APINebula", "", "https://apinebula.com", "https://apinebula.com/02rw5X",
      "third_party", false, true, "apinebula", "apinebula",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "AtlasCloud", "", "https://www.atlascloud.ai/console/coding-plan",
      "https://www.atlascloud.ai/console/coding-plan", "aggregator", false, true,
      "atlascloud", "atlascloud",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "SudoCode", "", "https://sudocode.us", "https://sudocode.us",
      "third_party", false, true, "sudocode", "sudocode",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "ClaudeAPI", "", "https://claudeapi.com", "https://console.claudeapi.com/register?aff=pCLD",
      "aggregator", false, true, "claudeapi", "claudeapi",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "ClaudeCN", "", "https://claudecn.top", "https://claudecn.top/register?aff=moongate",
      "third_party", false, true, "claudecn", "claudecn",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "RunAPI", "", "https://runapi.co", "https://runapi.co", "aggregator",
      false, true, "runapi", "runapi",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "RelaxyCode", "", "https://www.relaxycode.com", "https://www.relaxycode.com/register",
      "third_party", false, false, "", "relaxcode",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "Cubence", "", "https://cubence.com", "https://cubence.com/signup?code=MOONGATE&source=moongate",
      "third_party", false, true, "cubence", "cubence",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "AIGoCode", "", "https://aigocode.com", "https://aigocode.com",
      "third_party", false, true, "aigocode", "aigocode",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "RightCode", "", "https://www.right.codes", "https://www.right.codes/register?aff=MOONGATE",
      "third_party", false, true, "rightcode", "rc",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "AICodeMirror", "", "https://www.aicodemirror.com", "https://www.aicodemirror.com/register?invitecode=9915W3",
      "third_party", false, true, "aicodemirror", "aicodemirror",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "CrazyRouter", "", "https://www.crazyrouter.com", "https://www.crazyrouter.com/register?aff=OZcm&ref=moongate",
      "third_party", false, true, "crazyrouter", "crazyrouter",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "SSSAiCode", "", "https://sssaicodeapi.com", "https://sssaicodeapi.com/register?ref=DCP0SM",
      "third_party", false, true, "sssaicode", "sssaicode",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "Compshare", "providerForm.presets.ucloud", "https://www.compshare.cn",
      "https://www.compshare.cn/coding-plan?ytag=GPU_YY_YX_git_moongate", "aggregator",
      false, true, "ucloud", "ucloud",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "Compshare Coding Plan", "providerForm.presets.ucloudCoding",
      "https://www.compshare.cn", "https://www.compshare.cn/coding-plan?ytag=GPU_YY_YX_git_moongate",
      "aggregator", false, true, "ucloud", "ucloud",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "Micu", "", "https://www.micuapi.ai", "https://www.micuapi.ai/register?aff=aOYQ",
      "third_party", false, true, "micu", "micu",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "CTok.ai", "", "https://ctok.ai", "https://ctok.ai", "third_party",
      false, true, "ctok", "ctok",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "E-FlowCode", "", "https://e-flowcode.cc", "https://e-flowcode.cc",
      "third_party", false, false, "", "eflowcode",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "OpenRouter", "", "https://openrouter.ai", "https://openrouter.ai/keys",
      "aggregator", false, false, "", "openrouter",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "TheRouter", "", "https://therouter.ai", "https://dashboard.therouter.ai",
      "aggregator", false, false, "", "",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "Novita AI", "", "https://novita.ai", "https://novita.ai",
      "aggregator", false, false, "", "novita",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "LemonData", "", "https://lemondata.cc", "https://lemondata.cc/r/FFX1ZDUP",
      "third_party", false, true, "lemondata", "lemondata",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "Nvidia", "", "https://build.nvidia.com", "https://build.nvidia.com/settings/api-keys",
      "aggregator", false, false, "", "nvidia",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "PIPELLM", "", "https://code.pipellm.ai", "https://code.pipellm.ai/login?ref=uvw650za",
      "aggregator", false, false, "", "pipellm",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "Xiaomi MiMo", "", "https://platform.xiaomimimo.com", "https://platform.xiaomimimo.com/#/console/api-keys",
      "cn_official", false, false, "", "xiaomimimo",
    ),
    moon_provider_preset_summary_json(
      "claude-desktop", "Xiaomi MiMo Token Plan (China)", "", "https://platform.xiaomimimo.com/#/token-plan",
      "https://platform.xiaomimimo.com/#/console/plan-manage", "cn_official", false,
      false, "", "xiaomimimo",
    ),
    moon_provider_preset_summary_json(
      "codex", "OpenAI Official", "", "https://chatgpt.com/codex", "", "official",
      true, false, "", "openai",
    ),
    moon_provider_preset_summary_json(
      "codex", "Shengsuanyun", "providerForm.presets.shengsuanyun", "https://www.shengsuanyun.com/?from=CH_4HHXMRYF",
      "https://www.shengsuanyun.com/?from=CH_4HHXMRYF", "aggregator", false, true,
      "shengsuanyun", "shengsuanyun",
    ),
    moon_provider_preset_summary_json(
      "codex", "PatewayAI", "", "https://pateway.ai", "https://pateway.ai/?ch=etzpm8&aff=WB6M6F67#/",
      "third_party", false, true, "patewayai", "pateway",
    ),
    moon_provider_preset_summary_json(
      "codex", "火山Agentplan", "", "https://www.volcengine.com/activity/agentplan?utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "https://www.volcengine.com/activity/agentplan?utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "cn_official", false, true, "volcengine_agentplan", "huoshan",
    ),
    moon_provider_preset_summary_json(
      "codex", "BytePlus", "", "https://www.byteplus.com/en/product/modelark?utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "https://www.byteplus.com/en/product/modelark?utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "cn_official", false, true, "byteplus", "byteplus",
    ),
    moon_provider_preset_summary_json(
      "codex", "DouBaoSeed", "", "https://console.volcengine.com/ark/region:ark+cn-beijing/apiKey?apikey=%7B%7D&utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "https://console.volcengine.com/ark/region:ark+cn-beijing/apiKey?apikey=%7B%7D&utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "cn_official", false, true, "doubaoseed", "doubao",
    ),
    moon_provider_preset_summary_json(
      "codex", "CCSub", "", "https://www.ccsub.net", "https://www.ccsub.net/register?ref=Y6Z8DXEA",
      "aggregator", false, true, "ccsub", "ccsub",
    ),
    moon_provider_preset_summary_json(
      "codex", "Azure OpenAI", "", "https://learn.microsoft.com/en-us/azure/ai-foundry/openai/how-to/codex",
      "", "third_party", true, false, "", "azure",
    ),
    moon_provider_preset_summary_json(
      "codex", "DeepSeek", "", "https://platform.deepseek.com", "https://platform.deepseek.com/api_keys",
      "cn_official", false, false, "", "deepseek",
    ),
    moon_provider_preset_summary_json(
      "codex", "Zhipu GLM", "", "https://open.bigmodel.cn", "https://www.bigmodel.cn/claude-code?ic=RRVJPB5SII",
      "cn_official", false, false, "", "zhipu",
    ),
    moon_provider_preset_summary_json(
      "codex", "Zhipu GLM en", "", "https://z.ai", "https://z.ai/subscribe?ic=8JVLJQFSKB",
      "cn_official", false, false, "", "zhipu",
    ),
    moon_provider_preset_summary_json(
      "codex", "Baidu Qianfan Coding Plan", "", "https://cloud.baidu.com/product/qianfan_modelbuilder",
      "https://console.bce.baidu.com/qianfan/ais/console/applicationConsole/application",
      "cn_official", false, false, "", "baidu",
    ),
    moon_provider_preset_summary_json(
      "codex", "Bailian", "", "https://bailian.console.aliyun.com", "https://bailian.console.aliyun.com/#/api-key",
      "cn_official", false, false, "", "bailian",
    ),
    moon_provider_preset_summary_json(
      "codex", "Kimi", "", "https://platform.moonshot.cn/console?aff=moongate", "https://platform.moonshot.cn/console/api-keys?aff=moongate",
      "cn_official", false, false, "", "kimi",
    ),
    moon_provider_preset_summary_json(
      "codex", "StepFun", "", "https://platform.stepfun.com/step-plan", "https://platform.stepfun.com/interface-key",
      "cn_official", false, false, "", "stepfun",
    ),
    moon_provider_preset_summary_json(
      "codex", "StepFun en", "", "https://platform.stepfun.ai/step-plan", "https://platform.stepfun.ai/interface-key",
      "cn_official", false, false, "", "stepfun",
    ),
    moon_provider_preset_summary_json(
      "codex", "ModelScope", "", "https://modelscope.cn", "https://modelscope.cn/my/myaccesstoken",
      "aggregator", false, false, "", "modelscope",
    ),
    moon_provider_preset_summary_json(
      "codex", "Longcat", "", "https://longcat.chat/platform", "https://longcat.chat/platform/api_keys",
      "cn_official", false, false, "", "longcat",
    ),
    moon_provider_preset_summary_json(
      "codex", "MiniMax", "", "https://platform.minimaxi.com", "https://platform.minimaxi.com/subscribe/coding-plan",
      "cn_official", false, true, "minimax_cn", "minimax",
    ),
    moon_provider_preset_summary_json(
      "codex", "MiniMax en", "", "https://platform.minimax.io", "https://platform.minimax.io/subscribe/coding-plan",
      "cn_official", false, true, "minimax_en", "minimax",
    ),
    moon_provider_preset_summary_json(
      "codex", "BaiLing", "", "https://alipaytbox.yuque.com/sxs0ba/ling/get_started",
      "https://ling.tbox.cn/open", "cn_official", false, false, "", "",
    ),
    moon_provider_preset_summary_json(
      "codex", "Xiaomi MiMo", "", "https://platform.xiaomimimo.com", "https://platform.xiaomimimo.com/#/console/api-keys",
      "cn_official", false, false, "", "xiaomimimo",
    ),
    moon_provider_preset_summary_json(
      "codex", "Xiaomi MiMo Token Plan (China)", "", "https://platform.xiaomimimo.com/#/token-plan",
      "https://platform.xiaomimimo.com/#/console/plan-manage", "cn_official", false,
      false, "", "xiaomimimo",
    ),
    moon_provider_preset_summary_json(
      "codex", "SiliconFlow", "", "https://siliconflow.cn", "https://cloud.siliconflow.cn/i/drGuwc9k",
      "aggregator", false, true, "siliconflow", "siliconflow",
    ),
    moon_provider_preset_summary_json(
      "codex", "SiliconFlow en", "", "https://siliconflow.com", "https://cloud.siliconflow.cn/i/drGuwc9k",
      "aggregator", false, true, "siliconflow", "siliconflow",
    ),
    moon_provider_preset_summary_json(
      "codex", "Novita AI", "", "https://novita.ai", "https://novita.ai", "aggregator",
      false, false, "", "novita",
    ),
    moon_provider_preset_summary_json(
      "codex", "Nvidia", "", "https://build.nvidia.com", "https://build.nvidia.com/settings/api-keys",
      "aggregator", false, false, "", "nvidia",
    ),
    moon_provider_preset_summary_json(
      "codex", "AiHubMix", "", "https://aihubmix.com", "", "aggregator", false, false,
      "", "",
    ),
    moon_provider_preset_summary_json(
      "codex", "CherryIN", "", "https://open.cherryin.ai", "https://open.cherryin.ai/console/token",
      "aggregator", false, false, "", "cherryin",
    ),
    moon_provider_preset_summary_json(
      "codex", "DMXAPI", "", "https://www.dmxapi.cn", "", "aggregator", false, true,
      "dmxapi", "",
    ),
    moon_provider_preset_summary_json(
      "codex", "PackyCode", "", "https://www.packyapi.com", "https://www.packyapi.com/register?aff=moongate",
      "third_party", false, true, "packycode", "packycode",
    ),
    moon_provider_preset_summary_json(
      "codex", "APIKEY.FUN", "", "https://apikey.fun", "https://apikey.fun", "third_party",
      false, true, "apikeyfun", "apikeyfun",
    ),
    moon_provider_preset_summary_json(
      "codex", "APINebula", "", "https://apinebula.com", "https://apinebula.com/02rw5X",
      "third_party", false, true, "apinebula", "apinebula",
    ),
    moon_provider_preset_summary_json(
      "codex", "AtlasCloud", "", "https://www.atlascloud.ai/console/coding-plan",
      "https://www.atlascloud.ai/console/coding-plan", "aggregator", false, true,
      "atlascloud", "atlascloud",
    ),
    moon_provider_preset_summary_json(
      "codex", "SudoCode", "", "https://sudocode.us", "https://sudocode.us", "third_party",
      false, true, "sudocode", "sudocode",
    ),
    moon_provider_preset_summary_json(
      "codex", "ClaudeCN", "", "https://claudecn.top", "https://claudecn.top/register?aff=moongate",
      "third_party", false, true, "claudecn", "claudecn",
    ),
    moon_provider_preset_summary_json(
      "codex", "RunAPI", "", "https://runapi.co", "https://runapi.co", "aggregator",
      false, true, "runapi", "runapi",
    ),
    moon_provider_preset_summary_json(
      "codex", "RelaxyCode", "", "https://www.relaxycode.com", "https://www.relaxycode.com/register",
      "third_party", false, false, "", "relaxcode",
    ),
    moon_provider_preset_summary_json(
      "codex", "Cubence", "", "https://cubence.com", "https://cubence.com/signup?code=MOONGATE&source=moongate",
      "third_party", false, true, "cubence", "cubence",
    ),
    moon_provider_preset_summary_json(
      "codex", "AIGoCode", "", "https://aigocode.com", "https://aigocode.com", "third_party",
      false, true, "aigocode", "aigocode",
    ),
    moon_provider_preset_summary_json(
      "codex", "RightCode", "", "https://www.right.codes", "https://www.right.codes/register?aff=MOONGATE",
      "third_party", false, true, "rightcode", "rc",
    ),
    moon_provider_preset_summary_json(
      "codex", "AICodeMirror", "", "https://www.aicodemirror.com", "https://www.aicodemirror.com/register?invitecode=9915W3",
      "", false, true, "aicodemirror", "aicodemirror",
    ),
    moon_provider_preset_summary_json(
      "codex", "CrazyRouter", "", "https://www.crazyrouter.com", "https://www.crazyrouter.com/register?aff=OZcm&ref=moongate",
      "", false, true, "crazyrouter", "crazyrouter",
    ),
    moon_provider_preset_summary_json(
      "codex", "SSSAiCode", "", "https://sssaicodeapi.com", "https://sssaicodeapi.com/register?ref=DCP0SM",
      "third_party", false, true, "sssaicode", "sssaicode",
    ),
    moon_provider_preset_summary_json(
      "codex", "Compshare", "providerForm.presets.ucloud", "https://www.compshare.cn",
      "https://www.compshare.cn/coding-plan?ytag=GPU_YY_YX_git_moongate", "aggregator",
      false, true, "ucloud", "ucloud",
    ),
    moon_provider_preset_summary_json(
      "codex", "Compshare Coding Plan", "providerForm.presets.ucloudCoding", "https://www.compshare.cn",
      "https://www.compshare.cn/coding-plan?ytag=GPU_YY_YX_git_moongate", "aggregator",
      false, true, "ucloud", "ucloud",
    ),
    moon_provider_preset_summary_json(
      "codex", "Micu", "", "https://www.micuapi.ai", "https://www.micuapi.ai/register?aff=aOYQ",
      "third_party", false, true, "micu", "micu",
    ),
    moon_provider_preset_summary_json(
      "codex", "CTok.ai", "", "https://ctok.ai", "https://ctok.ai", "third_party",
      false, true, "ctok", "ctok",
    ),
    moon_provider_preset_summary_json(
      "codex", "E-FlowCode", "", "https://e-flowcode.cc", "https://e-flowcode.cc",
      "third_party", false, false, "", "eflowcode",
    ),
    moon_provider_preset_summary_json(
      "codex", "LemonData", "", "https://lemondata.cc", "https://lemondata.cc/r/FFX1ZDUP",
      "third_party", false, true, "lemondata", "lemondata",
    ),
    moon_provider_preset_summary_json(
      "codex", "PIPELLM", "", "https://code.pipellm.ai", "https://code.pipellm.ai/login?ref=uvw650za",
      "aggregator", false, false, "", "pipellm",
    ),
    moon_provider_preset_summary_json(
      "codex", "OpenRouter", "", "https://openrouter.ai", "https://openrouter.ai/keys",
      "aggregator", false, false, "", "openrouter",
    ),
    moon_provider_preset_summary_json(
      "codex", "TheRouter", "", "https://therouter.ai", "https://dashboard.therouter.ai",
      "aggregator", false, false, "", "",
    ),
    moon_provider_preset_summary_json(
      "gemini", "Google Official", "", "https://ai.google.dev/", "https://aistudio.google.com/apikey",
      "official", false, false, "google-official", "gemini",
    ),
    moon_provider_preset_summary_json(
      "gemini", "Shengsuanyun", "providerForm.presets.shengsuanyun", "https://www.shengsuanyun.com/?from=CH_4HHXMRYF",
      "https://www.shengsuanyun.com/?from=CH_4HHXMRYF", "aggregator", false, true,
      "shengsuanyun", "shengsuanyun",
    ),
    moon_provider_preset_summary_json(
      "gemini", "PackyCode", "", "https://www.packyapi.com", "https://www.packyapi.com/register?aff=moongate",
      "third_party", false, true, "packycode", "packycode",
    ),
    moon_provider_preset_summary_json(
      "gemini", "APIKEY.FUN", "", "https://apikey.fun", "https://apikey.fun", "third_party",
      false, true, "apikeyfun", "apikeyfun",
    ),
    moon_provider_preset_summary_json(
      "gemini", "APINebula", "", "https://apinebula.com", "https://apinebula.com/02rw5X",
      "third_party", false, true, "apinebula", "apinebula",
    ),
    moon_provider_preset_summary_json(
      "gemini", "SudoCode", "", "https://sudocode.us", "https://sudocode.us", "third_party",
      false, true, "sudocode", "sudocode",
    ),
    moon_provider_preset_summary_json(
      "gemini", "Cubence", "", "https://cubence.com", "https://cubence.com/signup?code=MOONGATE&source=moongate",
      "third_party", false, true, "cubence", "cubence",
    ),
    moon_provider_preset_summary_json(
      "gemini", "AIGoCode", "", "https://aigocode.com", "https://aigocode.com", "third_party",
      false, true, "aigocode", "aigocode",
    ),
    moon_provider_preset_summary_json(
      "gemini", "AICodeMirror", "", "https://www.aicodemirror.com", "https://www.aicodemirror.com/register?invitecode=9915W3",
      "third_party", false, true, "aicodemirror", "aicodemirror",
    ),
    moon_provider_preset_summary_json(
      "gemini", "CrazyRouter", "", "https://www.crazyrouter.com", "https://www.crazyrouter.com/register?aff=OZcm&ref=moongate",
      "third_party", false, true, "crazyrouter", "crazyrouter",
    ),
    moon_provider_preset_summary_json(
      "gemini", "SSSAiCode", "", "https://sssaicodeapi.com", "https://sssaicodeapi.com/register?ref=DCP0SM",
      "third_party", false, true, "sssaicode", "sssaicode",
    ),
    moon_provider_preset_summary_json(
      "gemini", "CTok.ai", "", "https://ctok.ai", "https://ctok.ai", "third_party",
      false, true, "ctok", "ctok",
    ),
    moon_provider_preset_summary_json(
      "gemini", "E-FlowCode", "", "https://e-flowcode.cc", "https://e-flowcode.cc",
      "third_party", false, false, "", "eflowcode",
    ),
    moon_provider_preset_summary_json(
      "gemini", "LemonData", "", "https://lemondata.cc", "https://lemondata.cc/r/FFX1ZDUP",
      "third_party", false, true, "lemondata", "lemondata",
    ),
    moon_provider_preset_summary_json(
      "gemini", "CherryIN", "", "https://open.cherryin.ai", "https://open.cherryin.ai/console/token",
      "aggregator", false, false, "", "cherryin",
    ),
    moon_provider_preset_summary_json(
      "gemini", "OpenRouter", "", "https://openrouter.ai", "https://openrouter.ai/keys",
      "aggregator", false, false, "", "openrouter",
    ),
    moon_provider_preset_summary_json(
      "gemini", "TheRouter", "", "https://therouter.ai", "https://dashboard.therouter.ai",
      "aggregator", false, false, "", "",
    ),
    moon_provider_preset_summary_json(
      "gemini", "自定义", "", "", "", "custom", false, false, "", "",
    ),
    moon_provider_preset_summary_json(
      "opencode", "Shengsuanyun", "providerForm.presets.shengsuanyun", "https://www.shengsuanyun.com/?from=CH_4HHXMRYF",
      "https://www.shengsuanyun.com/?from=CH_4HHXMRYF", "aggregator", false, true,
      "shengsuanyun", "shengsuanyun",
    ),
    moon_provider_preset_summary_json(
      "opencode", "火山Agentplan", "", "https://www.volcengine.com/activity/agentplan?utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "https://www.volcengine.com/activity/agentplan?utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "cn_official", false, true, "volcengine_agentplan", "huoshan",
    ),
    moon_provider_preset_summary_json(
      "opencode", "BytePlus", "", "https://www.byteplus.com/en/product/modelark?utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "https://www.byteplus.com/en/product/modelark?utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "cn_official", false, true, "byteplus", "byteplus",
    ),
    moon_provider_preset_summary_json(
      "opencode", "DouBaoSeed", "", "https://console.volcengine.com/ark/region:ark+cn-beijing/apiKey?apikey=%7B%7D&utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "https://console.volcengine.com/ark/region:ark+cn-beijing/apiKey?apikey=%7B%7D&utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "cn_official", false, true, "doubaoseed", "doubao",
    ),
    moon_provider_preset_summary_json(
      "opencode", "CCSub", "", "https://www.ccsub.net", "https://www.ccsub.net/register?ref=Y6Z8DXEA",
      "aggregator", false, true, "ccsub", "ccsub",
    ),
    moon_provider_preset_summary_json(
      "opencode", "DeepSeek", "", "https://platform.deepseek.com", "https://platform.deepseek.com/api_keys",
      "cn_official", false, false, "", "deepseek",
    ),
    moon_provider_preset_summary_json(
      "opencode", "Zhipu GLM", "", "https://open.bigmodel.cn", "https://www.bigmodel.cn/claude-code?ic=RRVJPB5SII",
      "cn_official", false, false, "", "zhipu",
    ),
    moon_provider_preset_summary_json(
      "opencode", "Zhipu GLM en", "", "https://z.ai", "https://z.ai/subscribe?ic=8JVLJQFSKB",
      "cn_official", false, false, "", "zhipu",
    ),
    moon_provider_preset_summary_json(
      "opencode", "Bailian", "", "https://bailian.console.aliyun.com", "https://bailian.console.aliyun.com/#/api-key",
      "cn_official", false, false, "", "bailian",
    ),
    moon_provider_preset_summary_json(
      "opencode", "Kimi k2.6", "", "https://platform.moonshot.cn/console?aff=moongate",
      "https://platform.moonshot.cn/console/api-keys?aff=moongate", "cn_official",
      false, false, "", "kimi",
    ),
    moon_provider_preset_summary_json(
      "opencode", "Kimi For Coding", "", "https://www.kimi.com/code/docs/?aff=moongate",
      "https://platform.moonshot.cn/console/api-keys?aff=moongate", "cn_official",
      false, false, "", "kimi",
    ),
    moon_provider_preset_summary_json(
      "opencode", "StepFun", "", "https://platform.stepfun.com/step-plan", "https://platform.stepfun.com/interface-key",
      "cn_official", false, false, "", "stepfun",
    ),
    moon_provider_preset_summary_json(
      "opencode", "StepFun en", "", "https://platform.stepfun.ai/step-plan", "https://platform.stepfun.ai/interface-key",
      "cn_official", false, false, "", "stepfun",
    ),
    moon_provider_preset_summary_json(
      "opencode", "StepFun Step Plan", "", "https://platform.stepfun.com/docs/zh/step-plan/overview",
      "https://platform.stepfun.com/interface-key", "cn_official", false, false,
      "", "stepfun",
    ),
    moon_provider_preset_summary_json(
      "opencode", "ModelScope", "", "https://modelscope.cn", "https://modelscope.cn/my/myaccesstoken",
      "aggregator", false, false, "", "modelscope",
    ),
    moon_provider_preset_summary_json(
      "opencode", "KAT-Coder", "", "https://console.streamlake.ai", "https://console.streamlake.ai/console/api-key",
      "cn_official", false, false, "", "catcoder",
    ),
    moon_provider_preset_summary_json(
      "opencode", "Longcat", "", "https://longcat.chat/platform", "https://longcat.chat/platform/api_keys",
      "cn_official", false, false, "", "longcat",
    ),
    moon_provider_preset_summary_json(
      "opencode", "MiniMax", "", "https://platform.minimaxi.com", "https://platform.minimaxi.com/subscribe/coding-plan",
      "cn_official", false, true, "minimax_cn", "minimax",
    ),
    moon_provider_preset_summary_json(
      "opencode", "MiniMax en", "", "https://platform.minimax.io", "https://platform.minimax.io/subscribe/coding-plan",
      "cn_official", false, true, "minimax_en", "minimax",
    ),
    moon_provider_preset_summary_json(
      "opencode", "BaiLing", "", "https://alipaytbox.yuque.com/sxs0ba/ling/get_started",
      "", "cn_official", false, false, "", "",
    ),
    moon_provider_preset_summary_json(
      "opencode", "Xiaomi MiMo", "", "https://platform.xiaomimimo.com", "https://platform.xiaomimimo.com/#/console/api-keys",
      "cn_official", false, false, "", "xiaomimimo",
    ),
    moon_provider_preset_summary_json(
      "opencode", "Xiaomi MiMo Token Plan (China)", "", "https://platform.xiaomimimo.com/#/token-plan",
      "https://platform.xiaomimimo.com/#/console/plan-manage", "cn_official", false,
      false, "", "xiaomimimo",
    ),
    moon_provider_preset_summary_json(
      "opencode", "AiHubMix", "", "https://aihubmix.com", "https://aihubmix.com",
      "aggregator", false, false, "", "aihubmix",
    ),
    moon_provider_preset_summary_json(
      "opencode", "CherryIN", "", "https://open.cherryin.ai", "https://open.cherryin.ai/console/token",
      "aggregator", false, false, "", "cherryin",
    ),
    moon_provider_preset_summary_json(
      "opencode", "DMXAPI", "", "https://www.dmxapi.cn", "https://www.dmxapi.cn",
      "aggregator", false, true, "dmxapi", "",
    ),
    moon_provider_preset_summary_json(
      "opencode", "OpenRouter", "", "https://openrouter.ai", "https://openrouter.ai/keys",
      "aggregator", false, false, "", "openrouter",
    ),
    moon_provider_preset_summary_json(
      "opencode", "TheRouter", "", "https://therouter.ai", "https://dashboard.therouter.ai",
      "aggregator", false, false, "", "",
    ),
    moon_provider_preset_summary_json(
      "opencode", "Novita AI", "", "https://novita.ai", "https://novita.ai", "aggregator",
      false, false, "", "novita",
    ),
    moon_provider_preset_summary_json(
      "opencode", "Nvidia", "", "https://build.nvidia.com", "https://build.nvidia.com/settings/api-keys",
      "aggregator", false, false, "", "nvidia",
    ),
    moon_provider_preset_summary_json(
      "opencode", "PIPELLM", "", "https://code.pipellm.ai", "https://code.pipellm.ai/login?ref=uvw650za",
      "aggregator", false, false, "", "pipellm",
    ),
    moon_provider_preset_summary_json(
      "opencode", "PackyCode", "", "https://www.packyapi.com", "https://www.packyapi.com/register?aff=moongate",
      "third_party", false, true, "packycode", "packycode",
    ),
    moon_provider_preset_summary_json(
      "opencode", "APIKEY.FUN", "", "https://apikey.fun", "https://apikey.fun", "third_party",
      false, true, "apikeyfun", "apikeyfun",
    ),
    moon_provider_preset_summary_json(
      "opencode", "APINebula", "", "https://apinebula.com", "https://apinebula.com/02rw5X",
      "third_party", false, true, "apinebula", "apinebula",
    ),
    moon_provider_preset_summary_json(
      "opencode", "AtlasCloud", "", "https://www.atlascloud.ai/console/coding-plan",
      "https://www.atlascloud.ai/console/coding-plan", "aggregator", false, true,
      "atlascloud", "atlascloud",
    ),
    moon_provider_preset_summary_json(
      "opencode", "SudoCode", "", "https://sudocode.us", "https://sudocode.us", "third_party",
      false, true, "sudocode", "sudocode",
    ),
    moon_provider_preset_summary_json(
      "opencode", "Cubence", "", "https://cubence.com", "https://cubence.com/signup?code=MOONGATE&source=moongate",
      "third_party", false, true, "cubence", "cubence",
    ),
    moon_provider_preset_summary_json(
      "opencode", "AIGoCode", "", "https://aigocode.com", "https://aigocode.com",
      "third_party", false, true, "aigocode", "aigocode",
    ),
    moon_provider_preset_summary_json(
      "opencode", "RightCode", "", "https://www.right.codes", "https://www.right.codes/register?aff=MOONGATE",
      "third_party", false, true, "rightcode", "rc",
    ),
    moon_provider_preset_summary_json(
      "opencode", "AICodeMirror", "", "https://www.aicodemirror.com", "https://www.aicodemirror.com/register?invitecode=9915W3",
      "third_party", false, true, "aicodemirror", "aicodemirror",
    ),
    moon_provider_preset_summary_json(
      "opencode", "ClaudeCN", "", "https://claudecn.top", "https://claudecn.top/register?aff=moongate",
      "third_party", false, true, "claudecn", "claudecn",
    ),
    moon_provider_preset_summary_json(
      "opencode", "RunAPI", "", "https://runapi.co", "https://runapi.co", "aggregator",
      false, true, "runapi", "runapi",
    ),
    moon_provider_preset_summary_json(
      "opencode", "CrazyRouter", "", "https://www.crazyrouter.com", "https://www.crazyrouter.com/register?aff=OZcm&ref=moongate",
      "third_party", false, true, "crazyrouter", "crazyrouter",
    ),
    moon_provider_preset_summary_json(
      "opencode", "SSSAiCode", "", "https://sssaicodeapi.com", "https://sssaicodeapi.com/register?ref=DCP0SM",
      "third_party", false, true, "sssaicode", "sssaicode",
    ),
    moon_provider_preset_summary_json(
      "opencode", "Micu", "", "https://www.micuapi.ai", "https://www.micuapi.ai/register?aff=aOYQ",
      "third_party", false, true, "micu", "micu",
    ),
    moon_provider_preset_summary_json(
      "opencode", "CTok.ai", "", "https://ctok.ai", "https://ctok.ai", "third_party",
      false, true, "ctok", "ctok",
    ),
    moon_provider_preset_summary_json(
      "opencode", "E-FlowCode", "", "https://e-flowcode.cc", "https://e-flowcode.cc",
      "third_party", false, false, "", "eflowcode",
    ),
    moon_provider_preset_summary_json(
      "opencode", "LemonData", "", "https://lemondata.cc", "https://lemondata.cc/r/FFX1ZDUP",
      "third_party", false, true, "lemondata", "lemondata",
    ),
    moon_provider_preset_summary_json(
      "opencode", "AWS Bedrock", "", "https://aws.amazon.com/bedrock/", "", "cloud_provider",
      false, false, "", "aws",
    ),
    moon_provider_preset_summary_json(
      "opencode", "OpenAI Compatible", "", "", "", "custom", false, false, "", "generic",
    ),
    moon_provider_preset_summary_json(
      "opencode", "Oh My OpenCode", "", "https://github.com/code-yeongyu/oh-my-openagent",
      "", "omo", false, false, "", "opencode",
    ),
    moon_provider_preset_summary_json(
      "opencode", "Oh My OpenCode Slim", "", "https://github.com/alvinunreal/oh-my-opencode-slim",
      "", "omo-slim", false, false, "", "opencode",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "Shengsuanyun", "providerForm.presets.shengsuanyun", "https://www.shengsuanyun.com/?from=CH_4HHXMRYF",
      "https://www.shengsuanyun.com/?from=CH_4HHXMRYF", "aggregator", false, true,
      "shengsuanyun", "shengsuanyun",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "火山Agentplan", "", "https://www.volcengine.com/activity/agentplan?utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "https://www.volcengine.com/activity/agentplan?utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "cn_official", false, true, "volcengine_agentplan", "huoshan",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "BytePlus", "", "https://www.byteplus.com/en/product/modelark?utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "https://www.byteplus.com/en/product/modelark?utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "cn_official", false, true, "byteplus", "byteplus",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "DouBaoSeed", "", "https://console.volcengine.com/ark/region:ark+cn-beijing/apiKey?apikey=%7B%7D&utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "https://console.volcengine.com/ark/region:ark+cn-beijing/apiKey?apikey=%7B%7D&utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "cn_official", false, true, "doubaoseed", "doubao",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "CCSub", "", "https://www.ccsub.net", "https://www.ccsub.net/register?ref=Y6Z8DXEA",
      "aggregator", false, true, "ccsub", "ccsub",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "DeepSeek", "", "https://platform.deepseek.com", "https://platform.deepseek.com/api_keys",
      "cn_official", false, false, "", "deepseek",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "Zhipu GLM", "", "https://open.bigmodel.cn", "https://www.bigmodel.cn/claude-code?ic=RRVJPB5SII",
      "cn_official", false, false, "", "zhipu",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "Zhipu GLM en", "", "https://z.ai", "https://z.ai/subscribe?ic=8JVLJQFSKB",
      "cn_official", false, false, "", "zhipu",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "Qwen Coder", "", "https://bailian.console.aliyun.com", "https://bailian.console.aliyun.com/#/api-key",
      "cn_official", false, false, "", "qwen",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "Kimi k2.6", "", "https://platform.moonshot.cn/console?aff=moongate",
      "https://platform.moonshot.cn/console/api-keys", "cn_official", false, false,
      "", "kimi",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "Kimi For Coding", "", "https://www.kimi.com/code/docs/?aff=moongate",
      "https://platform.moonshot.cn/console/api-keys", "cn_official", false, false,
      "", "kimi",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "StepFun", "", "https://platform.stepfun.com/step-plan", "https://platform.stepfun.com/interface-key",
      "cn_official", false, false, "", "stepfun",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "StepFun en", "", "https://platform.stepfun.ai/step-plan", "https://platform.stepfun.ai/interface-key",
      "cn_official", false, false, "", "stepfun",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "MiniMax", "", "https://platform.minimaxi.com", "https://platform.minimaxi.com/subscribe/coding-plan",
      "cn_official", false, true, "minimax_cn", "minimax",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "MiniMax en", "", "https://platform.minimax.io", "https://platform.minimax.io/subscribe/coding-plan",
      "cn_official", false, true, "minimax_en", "minimax",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "KAT-Coder", "", "https://console.streamlake.ai", "https://console.streamlake.ai/console/api-key",
      "cn_official", false, false, "", "catcoder",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "Longcat", "", "https://longcat.chat/platform", "https://longcat.chat/platform/api_keys",
      "cn_official", false, false, "", "longcat",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "BaiLing", "", "https://alipaytbox.yuque.com/sxs0ba/ling/get_started",
      "", "cn_official", false, false, "", "",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "Xiaomi MiMo", "", "https://platform.xiaomimimo.com", "https://platform.xiaomimimo.com/#/console/api-keys",
      "cn_official", false, false, "", "xiaomimimo",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "Xiaomi MiMo Token Plan (China)", "", "https://platform.xiaomimimo.com/#/token-plan",
      "https://platform.xiaomimimo.com/#/console/plan-manage", "cn_official", false,
      false, "", "xiaomimimo",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "AiHubMix", "", "https://aihubmix.com", "https://aihubmix.com",
      "aggregator", false, false, "", "aihubmix",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "CherryIN", "", "https://open.cherryin.ai", "https://open.cherryin.ai/console/token",
      "aggregator", false, false, "", "cherryin",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "DMXAPI", "", "https://www.dmxapi.cn", "https://www.dmxapi.cn",
      "aggregator", false, true, "dmxapi", "",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "ClaudeCN", "", "https://claudecn.top", "https://claudecn.top/register?aff=moongate",
      "third_party", false, true, "claudecn", "claudecn",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "RunAPI", "", "https://runapi.co", "https://runapi.co", "aggregator",
      false, true, "runapi", "runapi",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "OpenRouter", "", "https://openrouter.ai", "https://openrouter.ai/keys",
      "aggregator", false, false, "", "openrouter",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "TheRouter", "", "https://therouter.ai", "https://dashboard.therouter.ai",
      "aggregator", false, false, "", "",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "ModelScope", "", "https://modelscope.cn", "https://modelscope.cn/my/myaccesstoken",
      "aggregator", false, false, "", "modelscope",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "SiliconFlow", "", "https://siliconflow.cn", "https://cloud.siliconflow.cn/i/drGuwc9k",
      "aggregator", false, true, "siliconflow", "siliconflow",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "SiliconFlow en", "", "https://siliconflow.com", "https://cloud.siliconflow.cn/i/drGuwc9k",
      "aggregator", false, true, "siliconflow", "siliconflow",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "Novita AI", "", "https://novita.ai", "https://novita.ai", "aggregator",
      false, false, "", "novita",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "Nvidia", "", "https://build.nvidia.com", "https://build.nvidia.com/settings/api-keys",
      "aggregator", false, false, "", "nvidia",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "PIPELLM", "", "https://code.pipellm.ai", "https://code.pipellm.ai/login?ref=uvw650za",
      "aggregator", false, false, "", "pipellm",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "PackyCode", "", "https://www.packyapi.com", "https://www.packyapi.com/register?aff=moongate",
      "third_party", false, true, "packycode", "packycode",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "APIKEY.FUN", "", "https://apikey.fun", "https://apikey.fun", "third_party",
      false, true, "apikeyfun", "apikeyfun",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "APINebula", "", "https://apinebula.com", "https://apinebula.com/02rw5X",
      "third_party", false, true, "apinebula", "apinebula",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "AtlasCloud", "", "https://www.atlascloud.ai/console/coding-plan",
      "https://www.atlascloud.ai/console/coding-plan", "aggregator", false, true,
      "atlascloud", "atlascloud",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "SudoCode", "", "https://sudocode.us", "https://sudocode.us", "third_party",
      false, true, "sudocode", "sudocode",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "Cubence", "", "https://cubence.com", "https://cubence.com/signup?code=MOONGATE&source=moongate",
      "third_party", false, true, "cubence", "cubence",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "AIGoCode", "", "https://aigocode.com", "https://aigocode.com",
      "third_party", false, true, "aigocode", "aigocode",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "RightCode", "", "https://www.right.codes", "https://www.right.codes/register?aff=MOONGATE",
      "third_party", false, true, "rightcode", "rc",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "AICodeMirror", "", "https://www.aicodemirror.com", "https://www.aicodemirror.com/register?invitecode=9915W3",
      "third_party", false, true, "aicodemirror", "aicodemirror",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "CrazyRouter", "", "https://www.crazyrouter.com", "https://www.crazyrouter.com/register?aff=OZcm&ref=moongate",
      "third_party", false, true, "crazyrouter", "crazyrouter",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "SSSAiCode", "", "https://sssaicodeapi.com", "https://sssaicodeapi.com/register?ref=DCP0SM",
      "third_party", false, true, "sssaicode", "sssaicode",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "Compshare", "providerForm.presets.ucloud", "https://www.compshare.cn",
      "https://www.compshare.cn/coding-plan?ytag=GPU_YY_YX_git_moongate", "aggregator",
      false, true, "ucloud", "ucloud",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "Compshare Coding Plan", "providerForm.presets.ucloudCoding", "https://www.compshare.cn",
      "https://www.compshare.cn/coding-plan?ytag=GPU_YY_YX_git_moongate", "aggregator",
      false, true, "ucloud", "ucloud",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "Micu", "", "https://www.micuapi.ai", "https://www.micuapi.ai/register?aff=aOYQ",
      "third_party", false, true, "micu", "micu",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "CTok.ai", "", "https://ctok.ai", "https://ctok.ai", "third_party",
      false, true, "ctok", "ctok",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "E-FlowCode", "", "https://e-flowcode.cc", "https://e-flowcode.cc",
      "third_party", false, false, "", "eflowcode",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "LemonData", "", "https://lemondata.cc", "https://lemondata.cc/r/FFX1ZDUP",
      "third_party", false, true, "lemondata", "lemondata",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "AWS Bedrock", "", "https://aws.amazon.com/bedrock/", "", "cloud_provider",
      false, false, "", "aws",
    ),
    moon_provider_preset_summary_json(
      "openclaw", "OpenAI Compatible", "", "", "", "custom", false, false, "", "generic",
    ),
    moon_provider_preset_summary_json(
      "hermes", "Shengsuanyun", "providerForm.presets.shengsuanyun", "https://www.shengsuanyun.com/?from=CH_4HHXMRYF",
      "https://www.shengsuanyun.com/?from=CH_4HHXMRYF", "aggregator", false, true,
      "shengsuanyun", "shengsuanyun",
    ),
    moon_provider_preset_summary_json(
      "hermes", "火山Agentplan", "", "https://www.volcengine.com/activity/agentplan?utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "https://www.volcengine.com/activity/agentplan?utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "cn_official", false, true, "volcengine_agentplan", "huoshan",
    ),
    moon_provider_preset_summary_json(
      "hermes", "BytePlus", "", "https://www.byteplus.com/en/product/modelark?utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "https://www.byteplus.com/en/product/modelark?utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "cn_official", false, true, "byteplus", "byteplus",
    ),
    moon_provider_preset_summary_json(
      "hermes", "DouBaoSeed", "", "https://console.volcengine.com/ark/region:ark+cn-beijing/apiKey?apikey=%7B%7D&utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "https://console.volcengine.com/ark/region:ark+cn-beijing/apiKey?apikey=%7B%7D&utm_campaign=hw&utm_content=moongate&utm_medium=devrel_tool_web&utm_source=OWO&utm_term=moongate",
      "cn_official", false, true, "doubaoseed", "doubao",
    ),
    moon_provider_preset_summary_json(
      "hermes", "CCSub", "", "https://www.ccsub.net", "https://www.ccsub.net/register?ref=Y6Z8DXEA",
      "aggregator", false, true, "ccsub", "ccsub",
    ),
    moon_provider_preset_summary_json(
      "hermes", "OpenRouter", "providerForm.presets.openrouter", "https://openrouter.ai",
      "https://openrouter.ai/keys", "aggregator", false, false, "", "openrouter",
    ),
    moon_provider_preset_summary_json(
      "hermes", "DeepSeek", "providerForm.presets.deepseek", "https://platform.deepseek.com",
      "https://platform.deepseek.com/api_keys", "cn_official", false, false, "",
      "deepseek",
    ),
    moon_provider_preset_summary_json(
      "hermes", "Together AI", "providerForm.presets.together", "https://together.ai",
      "https://api.together.ai/settings/api-keys", "aggregator", false, false, "",
      "together",
    ),
    moon_provider_preset_summary_json(
      "hermes", "Nous Research", "", "https://nousresearch.com", "https://portal.nousresearch.com/",
      "official", true, false, "", "hermes",
    ),
    moon_provider_preset_summary_json(
      "hermes", "Zhipu GLM", "", "https://open.bigmodel.cn", "https://www.bigmodel.cn/claude-code?ic=RRVJPB5SII",
      "cn_official", false, false, "", "zhipu",
    ),
    moon_provider_preset_summary_json(
      "hermes", "Zhipu GLM en", "", "https://z.ai", "https://z.ai/subscribe?ic=8JVLJQFSKB",
      "cn_official", false, false, "", "zhipu",
    ),
    moon_provider_preset_summary_json(
      "hermes", "Bailian", "", "https://bailian.console.aliyun.com", "", "cn_official",
      false, false, "", "bailian",
    ),
    moon_provider_preset_summary_json(
      "hermes", "Bailian For Coding", "", "https://bailian.console.aliyun.com", "",
      "cn_official", false, false, "", "bailian",
    ),
    moon_provider_preset_summary_json(
      "hermes", "Kimi", "", "https://platform.moonshot.cn/console?aff=moongate",
      "", "cn_official", false, false, "", "kimi",
    ),
    moon_provider_preset_summary_json(
      "hermes", "Kimi For Coding", "", "https://www.kimi.com/code/docs/?aff=moongate",
      "", "cn_official", false, false, "", "kimi",
    ),
    moon_provider_preset_summary_json(
      "hermes", "StepFun", "", "https://platform.stepfun.ai", "https://platform.stepfun.ai/interface-key",
      "cn_official", false, false, "", "stepfun",
    ),
    moon_provider_preset_summary_json(
      "hermes", "ModelScope", "", "https://modelscope.cn", "", "aggregator", false,
      false, "", "modelscope",
    ),
    moon_provider_preset_summary_json(
      "hermes", "KAT-Coder", "", "https://console.streamlake.ai", "https://console.streamlake.ai/console/api-key",
      "cn_official", false, false, "", "catcoder",
    ),
    moon_provider_preset_summary_json(
      "hermes", "Longcat", "", "https://longcat.chat/platform", "https://longcat.chat/platform/api_keys",
      "cn_official", false, false, "", "longcat",
    ),
    moon_provider_preset_summary_json(
      "hermes", "MiniMax", "", "https://platform.minimaxi.com", "https://platform.minimaxi.com/subscribe/coding-plan",
      "cn_official", false, true, "minimax_cn", "minimax",
    ),
    moon_provider_preset_summary_json(
      "hermes", "MiniMax en", "", "https://platform.minimax.io", "https://platform.minimax.io/subscribe/coding-plan",
      "cn_official", false, true, "minimax_en", "minimax",
    ),
    moon_provider_preset_summary_json(
      "hermes", "BaiLing", "", "https://alipaytbox.yuque.com/sxs0ba/ling/get_started",
      "", "cn_official", false, false, "", "",
    ),
    moon_provider_preset_summary_json(
      "hermes", "AiHubMix", "", "https://aihubmix.com", "https://aihubmix.com", "aggregator",
      false, false, "", "aihubmix",
    ),
    moon_provider_preset_summary_json(
      "hermes", "CherryIN", "", "https://open.cherryin.ai", "https://open.cherryin.ai/console/token",
      "aggregator", false, false, "", "cherryin",
    ),
    moon_provider_preset_summary_json(
      "hermes", "SiliconFlow", "", "https://siliconflow.cn", "https://cloud.siliconflow.cn/i/drGuwc9k",
      "aggregator", false, true, "siliconflow", "siliconflow",
    ),
    moon_provider_preset_summary_json(
      "hermes", "SiliconFlow en", "", "https://siliconflow.com", "https://cloud.siliconflow.cn/i/drGuwc9k",
      "aggregator", false, true, "siliconflow", "siliconflow",
    ),
    moon_provider_preset_summary_json(
      "hermes", "DMXAPI", "", "https://www.dmxapi.cn", "https://www.dmxapi.cn", "aggregator",
      false, true, "dmxapi", "",
    ),
    moon_provider_preset_summary_json(
      "hermes", "PackyCode", "", "https://www.packyapi.com", "https://www.packyapi.com/register?aff=moongate",
      "third_party", false, true, "packycode", "packycode",
    ),
    moon_provider_preset_summary_json(
      "hermes", "APIKEY.FUN", "", "https://apikey.fun", "https://apikey.fun", "third_party",
      false, true, "apikeyfun", "apikeyfun",
    ),
    moon_provider_preset_summary_json(
      "hermes", "APINebula", "", "https://apinebula.com", "https://apinebula.com/02rw5X",
      "third_party", false, true, "apinebula", "apinebula",
    ),
    moon_provider_preset_summary_json(
      "hermes", "AtlasCloud", "", "https://www.atlascloud.ai/console/coding-plan",
      "https://www.atlascloud.ai/console/coding-plan", "aggregator", false, true,
      "atlascloud", "atlascloud",
    ),
    moon_provider_preset_summary_json(
      "hermes", "SudoCode", "", "https://sudocode.us", "https://sudocode.us", "third_party",
      false, true, "sudocode", "sudocode",
    ),
    moon_provider_preset_summary_json(
      "hermes", "Cubence", "", "https://cubence.com", "https://cubence.com/signup?code=MOONGATE&source=moongate",
      "third_party", false, true, "cubence", "cubence",
    ),
    moon_provider_preset_summary_json(
      "hermes", "ClaudeCN", "", "https://claudecn.top", "https://claudecn.top/register?aff=moongate",
      "third_party", false, true, "claudecn", "claudecn",
    ),
    moon_provider_preset_summary_json(
      "hermes", "RunAPI", "", "https://runapi.co", "https://runapi.co", "aggregator",
      false, true, "runapi", "runapi",
    ),
    moon_provider_preset_summary_json(
      "hermes", "AIGoCode", "", "https://aigocode.com", "https://aigocode.com", "third_party",
      false, true, "aigocode", "aigocode",
    ),
    moon_provider_preset_summary_json(
      "hermes", "RightCode", "", "https://www.right.codes", "https://www.right.codes/register?aff=MOONGATE",
      "third_party", false, true, "rightcode", "rc",
    ),
    moon_provider_preset_summary_json(
      "hermes", "AICodeMirror", "", "https://www.aicodemirror.com", "https://www.aicodemirror.com/register?invitecode=9915W3",
      "third_party", false, true, "aicodemirror", "aicodemirror",
    ),
    moon_provider_preset_summary_json(
      "hermes", "CrazyRouter", "", "https://www.crazyrouter.com", "https://www.crazyrouter.com/register?aff=OZcm&ref=moongate",
      "third_party", false, true, "crazyrouter", "crazyrouter",
    ),
    moon_provider_preset_summary_json(
      "hermes", "SSSAiCode", "", "https://sssaicodeapi.com", "https://sssaicodeapi.com/register?ref=DCP0SM",
      "third_party", false, true, "sssaicode", "sssaicode",
    ),
    moon_provider_preset_summary_json(
      "hermes", "Compshare", "providerForm.presets.ucloud", "https://www.compshare.cn",
      "https://www.compshare.cn/coding-plan?ytag=GPU_YY_YX_git_moongate", "aggregator",
      false, true, "ucloud", "ucloud",
    ),
    moon_provider_preset_summary_json(
      "hermes", "Compshare Coding Plan", "providerForm.presets.ucloudCoding", "https://www.compshare.cn",
      "https://www.compshare.cn/coding-plan?ytag=GPU_YY_YX_git_moongate", "aggregator",
      false, true, "ucloud", "ucloud",
    ),
    moon_provider_preset_summary_json(
      "hermes", "Micu", "", "https://www.micuapi.ai", "https://www.micuapi.ai/register?aff=aOYQ",
      "third_party", false, true, "micu", "micu",
    ),
    moon_provider_preset_summary_json(
      "hermes", "CTok.ai", "", "https://ctok.ai", "https://ctok.ai", "third_party",
      false, true, "ctok", "ctok",
    ),
    moon_provider_preset_summary_json(
      "hermes", "E-FlowCode", "", "https://e-flowcode.cc", "https://e-flowcode.cc",
      "third_party", false, false, "", "eflowcode",
    ),
    moon_provider_preset_summary_json(
      "hermes", "LemonData", "", "https://lemondata.cc", "https://lemondata.cc/r/FFX1ZDUP",
      "third_party", false, true, "lemondata", "lemondata",
    ),
    moon_provider_preset_summary_json(
      "hermes", "TheRouter", "", "https://therouter.ai", "https://dashboard.therouter.ai",
      "aggregator", false, false, "", "",
    ),
    moon_provider_preset_summary_json(
      "hermes", "Novita AI", "", "https://novita.ai", "https://novita.ai", "aggregator",
      false, false, "", "novita",
    ),
    moon_provider_preset_summary_json(
      "hermes", "Nvidia", "", "https://build.nvidia.com", "https://build.nvidia.com/settings/api-keys",
      "aggregator", false, false, "", "nvidia",
    ),
    moon_provider_preset_summary_json(
      "hermes", "PIPELLM", "", "https://code.pipellm.ai", "https://code.pipellm.ai/login?ref=uvw650za",
      "aggregator", false, false, "", "pipellm",
    ),
    moon_provider_preset_summary_json(
      "hermes", "Xiaomi MiMo", "", "https://platform.xiaomimimo.com", "https://platform.xiaomimimo.com/#/console/api-keys",
      "cn_official", false, false, "", "xiaomimimo",
    ),
    moon_provider_preset_summary_json(
      "hermes", "Xiaomi MiMo Token Plan (China)", "", "https://platform.xiaomimimo.com/#/token-plan",
      "https://platform.xiaomimimo.com/#/console/plan-manage", "cn_official", false,
      false, "", "xiaomimimo",
    ),
  ]
}
