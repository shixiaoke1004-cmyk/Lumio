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
        "appearance.topOffset": ("Content top offset", "内容下移距离"),

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

        "media.nothingPlaying": ("Nothing playing", "暂无播放"),
        "shelf.dropHere": ("Drop files here", "拖入文件暂存"),
        "shelf.clear": ("Clear", "清空"),
        "shelf.clear.help": ("Remove all items", "移除全部文件"),
        "shelf.airdrop": ("AirDrop", "隔空投送"),
        "shelf.airdrop.help": ("AirDrop all items", "隔空投送全部文件"),
    ]
}
