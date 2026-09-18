import Foundation

// MARK: - Chat Models

enum Role: String, Codable {
    case user
    case assistant
}

struct Attachment: Codable, Identifiable {
    let id: String
    let name: String
    let size: Int
    let mime: String
}

enum ToolName: String, Codable {
    case shell
    case writeFile = "write_file"
    case editFile = "edit_file"
    case readFile = "read_file"
    case listFiles = "list_files"
    case deleteFile = "delete_file"
    case buildZip = "build_zip"
    case presentFile = "present_file"

    var displayName: String {
        switch self {
        case .shell: return "Терминал"
        case .writeFile: return "Создать файл"
        case .editFile: return "Редактировать"
        case .readFile: return "Читать файл"
        case .listFiles: return "Список файлов"
        case .deleteFile: return "Удалить"
        case .buildZip: return "ZIP-архив"
        case .presentFile: return "Просмотр"
        }
    }

    var icon: String {
        switch self {
        case .shell: return "terminal"
        case .writeFile: return "doc.badge.plus"
        case .editFile: return "pencil"
        case .readFile: return "doc.text"
        case .listFiles: return "list.bullet"
        case .deleteFile: return "trash"
        case .buildZip: return "archivebox"
        case .presentFile: return "eye"
        }
    }
}

enum ToolStatus: String, Codable {
    case running
    case ok
    case error
}

struct ToolCall: Codable, Identifiable {
    let id: String
    let name: ToolName
    let args: [String: String]
    var status: ToolStatus
    var output: String?
    var ms: Int?
}

enum PartKind: String, Codable {
    case text
    case tool
}

enum Part: Codable, Identifiable {
    case text(String)
    case tool(ToolCall)

    var id: String {
        switch self {
        case .text(let text): return "text-\(text.hashValue)"
        case .tool(let call): return call.id
        }
    }
}

enum ArtifactKind: String, Codable {
    case code
    case html
    case markdown
    case image
    case zip
}

struct Artifact: Codable, Identifiable {
    let name: String
    let kind: ArtifactKind
    let content: String?
    let url: String?

    var id: String { name }
}

/// Версия пользовательского сообщения (как в вебе): текст + «хвост» —
/// всё, что шло после него в этой ветке диалога.
struct MessageVariant: Codable {
    var content: String
    var tail: [Message]
}

struct Message: Codable, Identifiable {
    let id: String
    let role: Role
    var content: String
    var attachments: [Attachment]?
    var parts: [Part]?
    var artifacts: [Artifact]?
    /// Все версии сообщения после редактирования (nil — сообщение не редактировалось).
    var variants: [MessageVariant]?
    /// Индекс текущей версии в `variants`.
    var variantIndex: Int?

    init(id: String = UUID().uuidString, role: Role, content: String,
         attachments: [Attachment]? = nil, parts: [Part]? = nil,
         artifacts: [Artifact]? = nil,
         variants: [MessageVariant]? = nil, variantIndex: Int? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.attachments = attachments
        self.parts = parts
        self.artifacts = artifacts
        self.variants = variants
        self.variantIndex = variantIndex
    }
}

struct ChatSession: Codable, Identifiable {
    let id: String
    var title: String
    var messages: [Message]
    var updatedAt: Date

    init(id: String = UUID().uuidString, title: String, messages: [Message] = [], updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.updatedAt = updatedAt
    }
}

// MARK: - Stream Events

enum StreamEvent {
    case text(String)
    case tool(id: String, name: ToolName, args: [String: String])
    case toolRes(id: String, ok: Bool, output: String, ms: Int)
    case artifact(name: String, kind: ArtifactKind, content: String?, url: String?)
    case done
}

extension StreamEvent: Decodable {
    enum CodingKeys: String, CodingKey {
        case t, v, id, name, args, ok, output, ms, kind, content, url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .t)

        switch type {
        case "text":
            let v = try container.decode(String.self, forKey: .v)
            self = .text(v)
        case "tool":
            let id = try container.decode(String.self, forKey: .id)
            let name = try container.decode(ToolName.self, forKey: .name)
            let args = try container.decodeIfPresent([String: String].self, forKey: .args) ?? [:]
            self = .tool(id: id, name: name, args: args)
        case "toolres":
            let id = try container.decode(String.self, forKey: .id)
            let ok = try container.decode(Bool.self, forKey: .ok)
            let output = try container.decode(String.self, forKey: .output)
            let ms = try container.decode(Int.self, forKey: .ms)
            self = .toolRes(id: id, ok: ok, output: output, ms: ms)
        case "artifact":
            let name = try container.decode(String.self, forKey: .name)
            let kind = try container.decode(ArtifactKind.self, forKey: .kind)
            let content = try container.decodeIfPresent(String.self, forKey: .content)
            let url = try container.decodeIfPresent(String.self, forKey: .url)
            self = .artifact(name: name, kind: kind, content: content, url: url)
        case "done":
            self = .done
        default:
            self = .done
        }
    }
}
