import SwiftUI

extension ColourThemeID {
    var palette: AppColourTheme {
        switch self {
        case .library: .library
        case .midnight: .midnight
        case .parchment: .parchment
        case .rose: .rose
        case .lavender: .lavender
        case .ocean: .ocean
        case .forest: .forest
        case .terracotta: .terracotta
        case .honey: .honey
        case .sage: .sage
        case .lagoon: .lagoon
        case .twilight: .twilight
        case .cherry: .cherry
        case .glacier: .glacier
        case .pearl: .pearl
        case .cocoa: .cocoa
        case .starlight: .starlight
        case .vip: .vip
        }
    }
}

struct AppColourTheme {
    let paper: Color
    let surface: Color
    let ink: Color
    let accent: Color
    let onAccent: Color
    let muted: Color
    let error: Color
    let colorScheme: ColorScheme
    let checkButtonBackground = Color(red: 0.18, green: 0.37, blue: 0.29)
    let checkButtonForeground: Color = .white
    var rewardGold: Color { colorScheme == .dark ? Color(red: 0.95, green: 0.78, blue: 0.35) : Color(red: 0.55, green: 0.36, blue: 0.07) }
    let coverInk: Color = .white
    let coverShadow: Color = .black
    // Book artwork keeps its identity while surrounding controls follow the theme.
    let coverColours: [Color] = [
        Color(red: 0.72, green: 0.35, blue: 0.23),
        Color(red: 0.25, green: 0.39, blue: 0.43),
        Color(red: 0.43, green: 0.45, blue: 0.27),
        Color(red: 0.51, green: 0.35, blue: 0.40),
        Color(red: 0.67, green: 0.46, blue: 0.24)
    ]
    static let library = AppColourTheme(
        paper: Color(red: 0.97, green: 0.96, blue: 0.93),
        surface: Color(red: 0.995, green: 0.99, blue: 0.98),
        ink: Color(red: 0.13, green: 0.23, blue: 0.22),
        accent: Color(red: 0.18, green: 0.37, blue: 0.29),
        onAccent: .white,
        muted: Color(red: 0.39, green: 0.43, blue: 0.39),
        error: Color(red: 0.68, green: 0.16, blue: 0.16),
        colorScheme: .light)
    static let midnight = AppColourTheme(
        paper: Color(red: 0.12, green: 0.16, blue: 0.20),
        surface: Color(red: 0.18, green: 0.23, blue: 0.28),
        ink: Color(red: 0.96, green: 0.97, blue: 0.95),
        accent: Color(red: 0.63, green: 0.83, blue: 0.69),
        onAccent: Color(red: 0.10, green: 0.18, blue: 0.14),
        muted: Color(red: 0.73, green: 0.78, blue: 0.81),
        error: Color(red: 1.0, green: 0.60, blue: 0.57),
        colorScheme: .dark)
    static let parchment = AppColourTheme(
        paper: Color(red: 0.97, green: 0.93, blue: 0.85),
        surface: Color(red: 0.995, green: 0.97, blue: 0.91),
        ink: Color(red: 0.25, green: 0.19, blue: 0.13),
        accent: Color(red: 0.48, green: 0.29, blue: 0.14),
        onAccent: Color(red: 1, green: 1, blue: 1),
        muted: Color(red: 0.43, green: 0.36, blue: 0.28),
        error: Color(red: 0.65, green: 0.16, blue: 0.14),
        colorScheme: .light)
    static let rose = AppColourTheme(
        paper: Color(red: 0.98, green: 0.94, blue: 0.94),
        surface: Color(red: 1, green: 0.98, blue: 0.97),
        ink: Color(red: 0.29, green: 0.17, blue: 0.22),
        accent: Color(red: 0.55, green: 0.25, blue: 0.36),
        onAccent: Color(red: 1, green: 1, blue: 1),
        muted: Color(red: 0.47, green: 0.36, blue: 0.4),
        error: Color(red: 0.65, green: 0.15, blue: 0.16),
        colorScheme: .light)
    static let lavender = AppColourTheme(
        paper: Color(red: 0.95, green: 0.94, blue: 0.98),
        surface: Color(red: 0.985, green: 0.98, blue: 1),
        ink: Color(red: 0.22, green: 0.19, blue: 0.32),
        accent: Color(red: 0.4, green: 0.31, blue: 0.57),
        onAccent: Color(red: 1, green: 1, blue: 1),
        muted: Color(red: 0.42, green: 0.39, blue: 0.49),
        error: Color(red: 0.65, green: 0.16, blue: 0.24),
        colorScheme: .light)
    static let ocean = AppColourTheme(
        paper: Color(red: 0.07, green: 0.16, blue: 0.21),
        surface: Color(red: 0.11, green: 0.23, blue: 0.29),
        ink: Color(red: 0.92, green: 0.97, blue: 0.98),
        accent: Color(red: 0.45, green: 0.82, blue: 0.88),
        onAccent: Color(red: 0.06, green: 0.17, blue: 0.21),
        muted: Color(red: 0.67, green: 0.8, blue: 0.84),
        error: Color(red: 1, green: 0.64, blue: 0.58),
        colorScheme: .dark)
    static let forest = AppColourTheme(
        paper: Color(red: 0.1, green: 0.16, blue: 0.13),
        surface: Color(red: 0.16, green: 0.23, blue: 0.19),
        ink: Color(red: 0.94, green: 0.96, blue: 0.89),
        accent: Color(red: 0.72, green: 0.83, blue: 0.49),
        onAccent: Color(red: 0.14, green: 0.2, blue: 0.1),
        muted: Color(red: 0.73, green: 0.79, blue: 0.69),
        error: Color(red: 1, green: 0.65, blue: 0.58),
        colorScheme: .dark)
    static let terracotta = AppColourTheme(
        paper: Color(red: 0.972549, green: 0.913725, blue: 0.870588),
        surface: Color(red: 1.0, green: 0.968627, blue: 0.941176),
        ink: Color(red: 0.282353, green: 0.160784, blue: 0.117647),
        accent: Color(red: 0.560784, green: 0.239216, blue: 0.145098),
        onAccent: Color(red: 1.0, green: 1.0, blue: 1.0),
        muted: Color(red: 0.439216, green: 0.341176, blue: 0.286275),
        error: Color(red: 0.631373, green: 0.14902, blue: 0.14902),
        colorScheme: .light)
    static let honey = AppColourTheme(
        paper: Color(red: 0.988235, green: 0.94902, blue: 0.835294),
        surface: Color(red: 1.0, green: 0.980392, blue: 0.92549),
        ink: Color(red: 0.254902, green: 0.215686, blue: 0.098039),
        accent: Color(red: 0.462745, green: 0.333333, blue: 0.070588),
        onAccent: Color(red: 1.0, green: 1.0, blue: 1.0),
        muted: Color(red: 0.419608, green: 0.376471, blue: 0.258824),
        error: Color(red: 0.631373, green: 0.14902, blue: 0.14902),
        colorScheme: .light)
    static let sage = AppColourTheme(
        paper: Color(red: 0.917647, green: 0.941176, blue: 0.894118),
        surface: Color(red: 0.972549, green: 0.988235, blue: 0.956863),
        ink: Color(red: 0.156863, green: 0.227451, blue: 0.164706),
        accent: Color(red: 0.258824, green: 0.376471, blue: 0.266667),
        onAccent: Color(red: 1.0, green: 1.0, blue: 1.0),
        muted: Color(red: 0.321569, green: 0.388235, blue: 0.309804),
        error: Color(red: 0.631373, green: 0.14902, blue: 0.14902),
        colorScheme: .light)
    static let lagoon = AppColourTheme(
        paper: Color(red: 0.031373, green: 0.164706, blue: 0.168627),
        surface: Color(red: 0.082353, green: 0.239216, blue: 0.235294),
        ink: Color(red: 0.901961, green: 0.964706, blue: 0.937255),
        accent: Color(red: 0.501961, green: 0.835294, blue: 0.741176),
        onAccent: Color(red: 0.031373, green: 0.164706, blue: 0.168627),
        muted: Color(red: 0.678431, green: 0.807843, blue: 0.768627),
        error: Color(red: 1.0, green: 0.658824, blue: 0.603922),
        colorScheme: .dark)
    static let twilight = AppColourTheme(
        paper: Color(red: 0.160784, green: 0.133333, blue: 0.227451),
        surface: Color(red: 0.231373, green: 0.188235, blue: 0.305882),
        ink: Color(red: 0.956863, green: 0.921569, blue: 1.0),
        accent: Color(red: 0.831373, green: 0.690196, blue: 0.941176),
        onAccent: Color(red: 0.160784, green: 0.133333, blue: 0.227451),
        muted: Color(red: 0.807843, green: 0.752941, blue: 0.866667),
        error: Color(red: 1.0, green: 0.678431, blue: 0.647059),
        colorScheme: .dark)
    static let cherry = AppColourTheme(
        paper: Color(red: 0.968627, green: 0.913725, blue: 0.941176),
        surface: Color(red: 1.0, green: 0.968627, blue: 0.984314),
        ink: Color(red: 0.282353, green: 0.12549, blue: 0.219608),
        accent: Color(red: 0.486275, green: 0.160784, blue: 0.294118),
        onAccent: Color(red: 1.0, green: 1.0, blue: 1.0),
        muted: Color(red: 0.447059, green: 0.313725, blue: 0.396078),
        error: Color(red: 0.631373, green: 0.14902, blue: 0.14902),
        colorScheme: .light)
    static let glacier = AppColourTheme(
        paper: Color(red: 0.917647, green: 0.952941, blue: 0.976471),
        surface: Color(red: 0.972549, green: 0.988235, blue: 1.0),
        ink: Color(red: 0.133333, green: 0.239216, blue: 0.317647),
        accent: Color(red: 0.141176, green: 0.356863, blue: 0.47451),
        onAccent: Color(red: 1.0, green: 1.0, blue: 1.0),
        muted: Color(red: 0.321569, green: 0.396078, blue: 0.458824),
        error: Color(red: 0.631373, green: 0.14902, blue: 0.14902),
        colorScheme: .light)
    static let pearl = AppColourTheme(
        paper: Color(red: 0.94902, green: 0.945098, blue: 0.929412),
        surface: Color(red: 1.0, green: 0.996078, blue: 0.980392),
        ink: Color(red: 0.203922, green: 0.207843, blue: 0.235294),
        accent: Color(red: 0.270588, green: 0.286275, blue: 0.337255),
        onAccent: Color(red: 1.0, green: 1.0, blue: 1.0),
        muted: Color(red: 0.380392, green: 0.380392, blue: 0.415686),
        error: Color(red: 0.631373, green: 0.14902, blue: 0.14902),
        colorScheme: .light)
    static let cocoa = AppColourTheme(
        paper: Color(red: 0.160784, green: 0.117647, blue: 0.101961),
        surface: Color(red: 0.235294, green: 0.168627, blue: 0.152941),
        ink: Color(red: 1.0, green: 0.941176, blue: 0.894118),
        accent: Color(red: 0.866667, green: 0.717647, blue: 0.576471),
        onAccent: Color(red: 0.160784, green: 0.117647, blue: 0.101961),
        muted: Color(red: 0.815686, green: 0.729412, blue: 0.690196),
        error: Color(red: 1.0, green: 0.678431, blue: 0.647059),
        colorScheme: .dark)
    static let starlight = AppColourTheme(
        paper: Color(red: 0.098039, green: 0.105882, blue: 0.188235),
        surface: Color(red: 0.160784, green: 0.168627, blue: 0.266667),
        ink: Color(red: 0.941176, green: 0.941176, blue: 1.0),
        accent: Color(red: 0.72549, green: 0.72549, blue: 0.945098),
        onAccent: Color(red: 0.098039, green: 0.105882, blue: 0.188235),
        muted: Color(red: 0.741176, green: 0.752941, blue: 0.866667),
        error: Color(red: 1.0, green: 0.678431, blue: 0.647059),
        colorScheme: .dark)
    static let vip = AppColourTheme(
        paper: Color(red: 0.08, green: 0.13, blue: 0.12),
        surface: Color(red: 0.14, green: 0.20, blue: 0.17),
        ink: Color(red: 0.99, green: 0.97, blue: 0.88),
        accent: Color(red: 0.92, green: 0.77, blue: 0.43),
        onAccent: Color(red: 0.12, green: 0.16, blue: 0.10),
        muted: Color(red: 0.77, green: 0.81, blue: 0.72),
        error: Color(red: 1, green: 0.65, blue: 0.58),
        colorScheme: .dark)
}
