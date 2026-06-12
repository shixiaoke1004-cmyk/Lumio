import Foundation

enum AppLanguage: String, CaseIterable {
    case system
    case english
    case chinese
}

enum ExpandedPosition: String, CaseIterable {
    case left
    case center
    case right
}

@MainActor
func L(_ key: String) -> String {
    L10n.string(key)
}

enum L10n {
    @MainActor
    static func string(_ key: String) -> String {
        guard let entry = table[key] else { return key }
        return isChinese ? entry.zh : entry.en
    }

    @MainActor
    static var isChinese: Bool {
        switch AppSettings.shared.language {
        case .chinese: true
        case .english: false
        case .system: Locale.preferredLanguages.first?.hasPrefix("zh") ?? false
        }
    }

    private static let table: [String: (en: String, zh: String)] = [
        "menu.about": ("About Lumio", "关于 Lumio"),
        "menu.settings": ("Settings…", "设置…"),
        "menu.quit": ("Quit Lumio", "退出 Lumio"),
        "settings.title": ("Lumio Settings", "Lumio 设置"),

        "section.general": ("General", "通用"),
        "section.appearance": ("Appearance", "外观"),
        "section.behavior": ("Behavior", "行为"),
        "section.features": ("Features", "功能"),

        "general.language": ("Language", "语言"),
        "language.system": ("System", "跟随系统"),
        "language.english": ("English", "English"),
        "language.chinese": ("Chinese", "简体中文"),
        "general.launchAtLogin": ("Launch at login", "开机自动启动"),

        "appearance.islandSize": ("Expanded size", "展开后大小"),
        "appearance.position": ("Expanded position", "展开位置"),
        "position.left": ("Left", "偏左"),
        "position.center": ("Center", "居中"),
        "position.right": ("Right", "偏右"),

        "behavior.hoverCompact": ("Show info while hovering", "悬停时显示紧凑信息"),
        "behavior.expandLock": ("Lock when expanded", "展开锁定"),
        "behavior.expandLock.hint": (
            "When locked, the island stays open until you press the close button.",
            "锁定后灵动岛保持展开，需点击关闭按钮才会收起。"
        ),
        "behavior.hudDuration": ("HUD display duration", "HUD 显示时长"),
        "behavior.activityDuration": ("Alert display duration", "提醒显示时长"),
        "unit.seconds": ("s", "秒"),

        "features.hud": ("Volume / brightness HUD takeover", "接管音量 / 亮度 HUD"),
        "features.hud.warning": (
            "Grant access in System Settings → Privacy & Security → Accessibility",
            "请在「系统设置 → 隐私与安全性 → 辅助功能」中授权"
        ),
        "features.gestures": ("Trackpad gestures on the notch", "刘海触控板手势"),
        "features.battery": ("Battery status alerts", "电池状态提醒"),
        "features.stealth": ("Stealth mode (hide from screen sharing)", "隐身模式（屏幕共享时隐藏）"),
        "features.stealth.hint": (
            "When on, the island is excluded from screen recording and sharing, so the other party can't see it.",
            "开启后灵动岛不会出现在录屏与屏幕共享中，对方看不到它。"
        ),

        "section.copilot": ("Copilot (Meetings & Interviews)", "Copilot（会议 / 面试助手）"),
        "copilot.enable": ("Enable AI copilot", "启用 AI 助手"),
        "copilot.backend": ("AI backend", "AI 后端"),
        "copilot.backend.custom": ("Custom (OpenAI-compatible)", "自定义（OpenAI 兼容）"),
        "copilot.apiKey": ("API Key", "API 密钥"),
        "copilot.model": ("Model", "模型"),
        "copilot.baseURL": ("Endpoint URL", "服务地址"),
        "copilot.scenario": ("Scenario", "场景"),
        "copilot.scenario.general": ("General", "通用"),
        "copilot.scenario.interview": ("Interview", "面试"),
        "copilot.scenario.meeting": ("Meeting", "会议"),
        "copilot.scenario.custom": ("Custom", "自定义"),
        "copilot.systemPrompt": ("Custom prompt", "自定义提示词"),
        "copilot.systemPrompt.hint": (
            "Define the copilot's role and answer style yourself; leave empty to fall back to the general prompt.",
            "自行定义助手的角色与回答风格；留空则回退到通用提示词。"
        ),
        "copilot.resume": ("Resume", "简历"),
        "copilot.resume.import": ("Import resume…", "导入简历…"),
        "copilot.resume.hint": (
            "PDF / TXT / Markdown. Text is extracted locally and sent to the AI with each question, or drop a file here.",
            "支持 PDF / TXT / Markdown，文本在本地提取，随每次提问发送给 AI；也可直接拖入文件。"
        ),
        "copilot.resume.importFailed": (
            "Couldn't extract text from that file.",
            "无法从该文件提取文本。"
        ),
        "copilot.resume.clear": ("Clear", "清除"),
        "copilot.jobDescription": ("Target job description", "目标职位描述（JD）"),
        "copilot.personaNotes": ("Additional instructions", "补充设定"),
        "copilot.personaNotes.hint": (
            "Anything else the AI should know: strengths to highlight, topics to avoid, preferred tone…",
            "其他希望 AI 了解的信息：要突出的优势、需回避的话题、偏好的语气等。"
        ),
        "copilot.eager": ("Eager answers (reply before they finish)", "抢答模式（对方话音未落即回答）"),
        "copilot.eager.hint": (
            "Starts answering once the live transcript holds still for a moment, instead of waiting for the sentence to be finalized. Uses more API calls.",
            "转写文本短暂稳定后立即提问，无需等待整句确认，回答更快但会消耗更多 API 调用。"
        ),
        "copilot.regenerate": ("Regenerate answer", "重新生成回答"),
        "copilot.hotkey.hint": (
            "Press ⌥Space anywhere (even in full-screen calls) to summon the copilot.",
            "在任何界面（包括全屏通话）按 ⌥空格 即可唤出助手。"
        ),
        "copilot.permission.screen.short": (
            "Screen Recording permission needed for call audio (Privacy & Security → Screen & System Audio Recording)",
            "需要「屏幕录制」权限才能听到通话声音（隐私与安全性 → 屏幕与系统录音）"
        ),
        "copilot.permission.speech.short": (
            "Speech Recognition permission needed for transcription (Privacy & Security → Speech Recognition)",
            "需要「语音识别」权限才能转写（隐私与安全性 → 语音识别）"
        ),
        "copilot.placeholder": (
            "Ask a question, or paste what the other party asked — the answer streams here.",
            "输入问题，或粘贴对方提出的问题，AI 回答建议会在这里流式显示。"
        ),
        "copilot.inputPlaceholder": ("Ask AI for a suggestion…", "向 AI 询问建议…"),
        "copilot.listen.help": (
            "Listen to the call and transcribe the other party",
            "监听通话并转写对方语音"
        ),
        "copilot.listening": ("Listening…", "正在监听…"),
        "copilot.notListening": (
            "Tap the waveform to transcribe the other party",
            "点击波形图标开始转写对方语音"
        ),
        "copilot.suggest": ("Suggest", "建议回答"),
        "copilot.thinking": ("Thinking…", "思考中…"),
        "copilot.copy": ("Copy answer", "复制回答"),
        "copilot.clear": ("Clear conversation", "清空对话"),
        "copilot.auto.help": (
            "Auto-suggest: answer each time the other party finishes speaking",
            "自动建议：对方每说完一句就自动给出回答建议"
        ),
        "copilot.transcript.title": ("Transcript", "转写记录"),
        "copilot.transcript.empty": ("No transcript yet", "暂无转写记录"),
        "copilot.speaker.me": ("Me", "我"),
        "copilot.speaker.other": ("Them", "对方"),
        "copilot.transcribeSelf": ("Transcribe my voice (microphone)", "转写我的语音（麦克风）"),
        "copilot.permission.mic": (
            "Microphone permission is required to transcribe your own voice. Grant it in System Settings → Privacy & Security → Microphone.",
            "需要「麦克风」权限才能转写你自己的语音。请在「系统设置 → 隐私与安全性 → 麦克风」中授权。"
        ),
        "copilot.permission.mic.short": (
            "Microphone permission needed to transcribe your voice (Privacy & Security → Microphone)",
            "需要「麦克风」权限才能转写你的语音（隐私与安全性 → 麦克风）"
        ),
        "copilot.permission.screen": (
            "Screen Recording permission is required to hear the call. Grant it in System Settings → Privacy & Security → Screen & System Audio Recording, then try again.",
            "需要「屏幕录制」权限才能听到通话声音。请在「系统设置 → 隐私与安全性 → 屏幕与系统录音」中授权后重试。"
        ),
        "copilot.permission.speech": (
            "Speech Recognition permission is required for transcription. Grant it in System Settings → Privacy & Security → Speech Recognition.",
            "需要「语音识别」权限才能转写。请在「系统设置 → 隐私与安全性 → 语音识别」中授权。"
        ),
        "copilot.stealth.help": (
            "Stealth mode: hide the island from screen sharing",
            "隐身模式：屏幕共享时隐藏灵动岛"
        ),

        "media.nothingPlaying": ("Nothing playing", "暂无播放"),
        "shelf.dropHere": ("Drop files here", "拖入文件暂存"),
        "shelf.clear": ("Clear", "清空"),
        "shelf.clear.help": ("Remove all items", "移除全部文件"),
        "shelf.airdrop": ("AirDrop", "隔空投送"),
        "shelf.airdrop.help": ("AirDrop all items", "隔空投送全部文件"),
    ]
}
