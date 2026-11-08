import Foundation
import SwiftData

enum LearningStatus: String, CaseIterable, Identifiable {
    case new, learning, known
    var id: String { rawValue }
    var title: String {
        switch self {
        case .new: "New"
        case .learning: "Learning"
        case .known: "Known"
        }
    }
}

struct WordSeed: Codable {
    let id: String
    let sourceID: Int
    let order: Int
    let english: String
    let swedish: String
    let sentence: String
    let sentenceEnglish: String
    let topic: String
    let symbol: String
    let imageName: String?
    let imageContainsText: Bool
}

struct VocabularyCatalog: Decodable {
    let entryCount: Int
    let entries: [Entry]

    struct Entry: Decodable {
        let id: String
        let sourceID: Int
        let english: String
        let swedish: String
    }
}

struct SentenceSeed: Decodable {
    let id: String
    let sentence: String
    let sentenceEnglish: String
}

@Model
final class VocabularyWord {
    @Attribute(.unique) var id: String
    var sourceID: Int
    var order: Int
    var english: String
    var swedish: String
    var sentence: String
    var sentenceEnglish: String
    var topic: String
    var symbol: String
    var imageName: String?
    var imageContainsText: Bool
    var statusRaw: String
    var reviewCount: Int
    var lastReviewed: Date?

    var status: LearningStatus {
        get { LearningStatus(rawValue: statusRaw) ?? .new }
        set { statusRaw = newValue.rawValue }
    }

    init(seed: WordSeed) {
        id = seed.id
        sourceID = seed.sourceID
        order = seed.order
        english = seed.english
        swedish = seed.swedish
        sentence = seed.sentence
        sentenceEnglish = seed.sentenceEnglish
        topic = seed.topic
        symbol = seed.symbol
        imageName = seed.imageName
        imageContainsText = seed.imageContainsText
        statusRaw = LearningStatus.new.rawValue
        reviewCount = 0
    }
}

@Model
final class ReviewEvent {
    @Attribute(.unique) var id: UUID
    var wordID: String
    var outcome: String
    var date: Date

    init(wordID: String, outcome: LearningStatus, date: Date = .now) {
        id = UUID()
        self.wordID = wordID
        self.outcome = outcome.rawValue
        self.date = date
    }
}

struct ReviewSnapshot {
    let wordID: String
    let previousStatus: LearningStatus
    let previousCount: Int
    let previousDate: Date?
    let event: ReviewEvent
}

enum ReviewScope: String, CaseIterable, Identifiable {
    case remaining, new, learning, known, all
    var id: String { rawValue }
    var title: String {
        switch self {
        case .remaining: "New & learning"
        case .new: "New words"
        case .learning: "Still learning"
        case .known: "Known words"
        case .all: "All words"
        }
    }
    func includes(_ word: VocabularyWord) -> Bool {
        switch self {
        case .remaining: word.status != .known
        case .new: word.status == .new
        case .learning: word.status == .learning
        case .known: word.status == .known
        case .all: true
        }
    }
}

// Topic membership is a view of an existing word, not another persisted copy.
// Keep the model schema and stable IDs unchanged so updates retain learning history.
enum VocabularyTopic: String, CaseIterable, Identifiable {
    case background = "Me & my background"
    case home = "Home & living"
    case shopping = "Shopping & services"
    case culture = "Culture & leisure"
    case travel = "Travel & transport"
    case health = "Health & wellbeing"
    case work = "Work & study"
    case nature = "Environment & nature"
    case society = "Society"
    case essentials = "Grammar & linking words"
    case commonVerbs = "Everyday verbs"
    case communicationVerbs = "Thinking & communication verbs"
    case adjectives = "Adjectives"
    case adverbs = "Adverbs"
    case timeNumbers = "Time, numbers & colours"
    case nouns = "Everyday nouns & ideas"

    var id: String { rawValue }
    var swedish: String {
        switch self {
        case .background: "Jag och min bakgrund"
        case .home: "Hem och boende"
        case .shopping: "Inköp och tjänster"
        case .culture: "Kultur och fritid"
        case .travel: "Resor och trafik"
        case .health: "Hälsa och välbefinnande"
        case .work: "Arbete och studier"
        case .nature: "Miljö och natur"
        case .society: "Samhälle"
        case .essentials: "Grammatik och småord"
        case .commonVerbs: "Vardagsverb"
        case .communicationVerbs: "Tanke- och talverb"
        case .adjectives: "Adjektiv"
        case .adverbs: "Adverb"
        case .timeNumbers: "Tid, tal och färger"
        case .nouns: "Substantiv i vardagen"
        }
    }
    var symbol: String {
        switch self {
        case .background: "person.crop.circle"
        case .home: "house"
        case .shopping: "basket"
        case .culture: "theatermasks"
        case .travel: "tram"
        case .health: "heart"
        case .work: "briefcase"
        case .nature: "leaf"
        case .society: "building.columns"
        case .essentials: "link"
        case .commonVerbs: "figure.walk"
        case .communicationVerbs: "bubble.left.and.bubble.right"
        case .adjectives: "textformat.size"
        case .adverbs: "speedometer"
        case .timeNumbers: "clock"
        case .nouns: "square.stack.3d.up"
        }
    }
    var detail: String {
        switch self {
        case .background: "Family, relationships & your story"
        case .home: "Housing, renting & daily chores"
        case .shopping: "Food, money & everyday services"
        case .culture: "Hobbies, media & celebrations"
        case .travel: "Transport, directions & holidays"
        case .health: "Your body, feelings & appointments"
        case .work: "Jobs, education & learning"
        case .nature: "Weather, wildlife & the environment"
        case .society: "Public life, rights & responsibilities"
        case .essentials: "Pronouns, connecting words & modal expressions"
        case .commonVerbs: "Actions, movement & daily routines"
        case .communicationVerbs: "Speaking, thinking, feelings & decisions"
        case .adjectives: "Qualities, states & descriptions"
        case .adverbs: "How, where & how often"
        case .timeNumbers: "Dates, quantities, measurements & colours"
        case .nouns: "Objects, people, ideas & everyday concepts"
        }
    }

    // Exact headword matches avoid classifying a word by unrelated example text.
    private static let headwords: [String: Set<VocabularyTopic>] = {
        let groups: [(VocabularyTopic, String)] = [
            (.background, "adult|age|alone|anniversary|aunt|baby|background|belief|birth|birthday|born|boy|boyfriend|bride|brother|child|childhood|couple|cousin|dad|daughter|dear|divorced|elderly|engaged|family|father|female|friend|friendly|friendship|gender|generation|girl|girlfriend|grandfather|grandmother|grandparent|greet|guy|hello|hi|human|husband|identity|individual|introduce|introduction|invitation|invite|kid|kiss|lady|language|life|live (reside)|living|lonely|love|male|man|marriage|married|marry|meet|member|mom|mother|name|native|neighbor|parent|partner|people|person|personal|personality|pet|relationship|relative|religion|religious|romantic|self|senior|sex|sexual|shy|single|sister|son|stranger|teenage|teenager|twin|uncle|wedding|welcome|wife|woman|young|youth|appearance|blond|brave|character|cheerful|clever|confident|curly|generous|gentle|honest|humorous|impatient|intelligent|kind (caring)|lazy|lively|manner|polite|rude|sensible|sensitive|sincere|smart|wise|ability|ambition|attitude|behave|behavior|conversation|communicate|communication|dialogue|disagree|discussion|opinion|respect|trust|argument|argue|apologize|forgive|thank|thanks"),
            (.home, "alarm|apartment|architecture|bath|bathroom|bed|bedroom|bell|blanket|bottle|bowl|box|brush|build|building|cable|carpet|ceiling|chair|clean|clock|closet|cloth|comfort|comfortable|construction|container|cook|cooking|corner|cup|cupboard|curtain|decorate|decoration|desk|dirt|dirty|dish|domestic|door|downstairs|dust|electric|electrical|electricity|elevator|entrance|estate|fence|fix|flat|floor|fork|frame|furniture|garage|garden|garbage|gas|gate|glass|guest|hall|heat|heating|home|house|household|housing|indoor|indoors|install|iron|key|kitchen|knife|lamp|light (from the sun/a lamp)|live (reside)|living|lock|mess|mirror|move|neat|neighbor|neighborhood|oven|owner|paint|pan|pipe|plastic|plate|plug|pot|property|rent|repair|resident|roof|room|rubber|sheet|shelf|shelter|shower|sink|soap|spoon|stair|steel|stone|stove|sweep|table|tap|telephone|temperature|toilet|tool|towel|trash|upstairs|wall|wash|washing|waste|water|window|wire|wood|wooden|yard|carry|close (shut)|closed|open|opening|shut|break|broken|damage|dry|fill|fold|folding|hang|lay|lie (be horizontal)|lift|pack|pour|replace|set (put)|tidy|warm|wet"),
            (.shopping, "ad|advertise|advertisement|advertising|afford|apple|bag|bake|banana|bank (money)|bar|bean|beef|beer|belt|bill|borrow|boot|brand|bread|breakfast|budget|butter|buy|cafe|cake|can (container)|cancel|candy|cap|card|carrot|cash|cent|chain|charge|cheap|check|cheese|chef|chicken|chip|chocolate|client|clothes|clothing|coat|coffee|coin|commercial|complain|complaint|consume|consumer|cook|cookie|cooking|corn|cost|cotton|cream|credit|currency|customer|debt|delicious|deliver|delivery|dessert|diamond|dinner|discount|dollar|dress|dressed|drink|eat|egg|euro|exchange|expense|expensive|fashion|fashionable|fee|finance|financial|fish|flour|food|fork|fresh|frozen|fruit|fry|gift|glove|goods|grocery|guarantee|hat|hungry|ice cream|ingredient|insurance|item|jacket|jam|jeans|jewelry|juice|label|leather|lemon|lend|loan|lunch|luxury|mail|mall|market|meal|meat|menu|milk|money|nut|offer|oil|onion|order|owe|package|pants|pay|payment|penny|pepper|pizza|pocket|post|pound|price|product|purchase|quality|receipt|refund|restaurant|return|rice|ring (jewelry/circle)|salad|sale|salt|sandwich|sauce|save|saving|selection|sell|serve|service|shirt|shoe|shop|shopping|silk|size|skirt|slice|sneaker|sock|soup|spend|spending|spicy|stamp|stock|store|sugar|suit|supermarket|supply|sweater|sweet|taste|tea|thirsty|tie|tip|tomato|trade|T-shirt|underwear|valuable|value|vegetable|waiter|wear|wine|wool|wrap|account|balance|available|booking|cashier|reservation|reserve|appointment"),
            (.culture, "act|actor|actress|activity|adventure|album|ancient|anniversary|app|art|article|artist|artistic|athlete|attract|attraction|audience|audio|author|award|ball|band|baseball|basketball|beat|bet|blog|book|bored|boring|broadcast|camera|camp|camping|cartoon|celebrate|celebration|celebrity|ceremony|champion|channel|chapter|character|church|classic|classical|club|coach|collect|collection|comedy|compete|competition|competitive|competitor|concert|contemporary|contest|costume|create|creation|creative|critic|cultural|culture|custom|cycle|dance|dancer|dancing|digital|documentary|drama|dramatic|draw|drawing|drum|edit|edition|editor|entertain|entertainment|episode|event|exhibit|exhibition|festival|fiction|film|fishing|fitness|folk|football|fun|funny|gallery|game|genre|golf|guitar|gym|hike|historic|historical|history|hobby|hockey|holiday|horror|host|humor|humorous|hunting|illustrate|illustration|image|imaginary|imagination|imagine|instrument|internet|jazz|joke|journal|journalist|jump|kick|league|leisure|library|listener|literature|live (broadcast)|magazine|magic|match (contest/correspond)|match (contest)|media|movie|museum|music|musical|musician|mysterious|mystery|narrative|news|newspaper|novel|online|paint|painter|painting|participant|participate|party|perform|performance|photo|photograph|photographer|photography|piano|picture|play|player|plot|podcast|poem|poet|poetry|pool|pop|popular|popularity|portrait|poster|press|prize|program|publish|radio|read|reader|reading|record|recording|reporter|review|rhythm|rock (music)|role|run|runner|running|scene|score|screen|script|series|shoot|shooting|show|sing|singer|singing|ski|skiing|soccer|song|sound|speaker|sport|stadium|stage|statue|story|studio|style|swim|swimming|tale|talent|talented|team|television|tennis|text|theater|ticket|tour|toy|track|tradition|traditional|trainer|training|tune|TV|venue|video|viewer|visit|visitor|voice|volume|watch|web|website|Wi-Fi|win|winner|write|writer|writing|written"),
            (.travel, "abroad|accident|accompany|adventure|air|aircraft|airline|airport|arrival|arrive|backward|bag|bicycle / bike|bicycle|board|boat|border|bridge|bus|camp|camping|cancel|capital|car|captain|city|coast|continent|country|countryside|crash|crew|cross|crowd|crowded|currency|delay|departure|destination|direction|distance|downtown|drive|driver|driving|east|eastern|engine|enter|entrance|exit|exploration|explore|far|fasten|flight|fly|flying|foreign|fuel|gate|go|guide|helicopter|highway|holiday|hotel|hurry|international|island|journey|kilometer|land|leave|left|license|local|locate|located|location|lost|luggage|map|mile|motor|motorcycle|north|northern|overseas|pack|park|parking|passenger|passport|path|petrol|pilot|place|plane|platform|port|public|rail|railroad|railway|reach|region|reservation|reserve|resort|return|ride|road|route|safety|sail|sailing|sailor|seat|ship|south|southern|speed|station|stay|street|subway|suitcase|taxi|tent|ticket|tire|tour|tourism|tourist|town|traffic|train|transfer|transport|transportation|travel|traveler|trip|truck|tunnel|underground|urban|vacation|van|vehicle|via|village|visit|visitor|wait|walk|way|west|western|wheel|zone|stop|turn|round|straight|near|nearby|opposite"),
            (.health, "afraid|aid|alcohol|alcoholic|alive|anger|angry|ankle|anxious|arm|ashamed|asleep|bacteria|balance|bath|beautiful|beauty|bitter|blind|blood|body|bone|brain|breast|breath|breathe|breathing|burn|calm|cancer|care|cell|chest|cigarette|cold|conscious|courage|crazy|cry|cure|dead|death|depressed|depressing|dentist|desperate|die|diet|disappointed|disease|doctor|drug|drunk|ear|eat|embarrassed|embarrassing|emergency|emotion|emotional|energy|excited|excitement|exercise|eye|face|fat|fear|feel|feeling|fever|finger|fit|fitness|flu|foot|frighten|frightened|frightening|hair|hand|happily|happiness|happy|harm|harmful|head|headache|health|healthy|hear|hearing|heart|heel|height|hope|hospital|hungry|hurt|ill|illness|infection|injure|injured|injury|joy|knee|leg|lifestyle|lip|lung|mad|medical|medicine|memory|mental|mood|mouth|muscle|nail|neck|nerve|nervous|nightmare|nose|nurse|operation|organ|pain|painful|pale|patient|physical|poison|poisonous|pregnant|pressure|recover|recovery|relax|relaxed|relief|relieved|rest (sleep/relax)|sad|sadly|satisfied|scared|scary|shock|shocked|shoulder|sick|sight|skin|sleep|smell|smile|smoke|smoking|stomach|strength|stress|stretch|strong|suffer|surgery|survive|sweat|sympathy|symptom|tear (drop from the eye)|temperature|therapy|thin|thirsty|throat|tired|toe|tongue|tooth|treat|treatment|uncomfortable|unconscious|unhappy|upset|vaccine|virus|vision|vitamin|wake|weak|weakness|weigh|weight|well|well-being|worried|worry|wound"),
            (.work, "academic|access|account|accurate|achieve|achievement|acquire|administration|advance|advanced|advantage|agenda|agent|AI|aim|ambition|analysis|analyze|application|apply|appointment|architect|assess|assessment|assignment|assist|assistant|attend|attention|award|boss|budget|business|businessman|busy|calculate|campus|candidate|capacity|career|category|chart|chemistry|chief|class|classroom|clause|clerk|client|code|colleague|college|commercial|commission|commitment|company|competitive|computer|concentrate|concentration|concept|conference|construct|construction|contract|copy|corporate|course|criterion|data|deadline|define|definition|degree|department|design|designer|desk|detail|detailed|develop|development|device|diagram|dictionary|digital|diploma|director|discipline|dismiss|document|draft|duty|earn|economic|economy|educate|educated|education|educational|effective|effectively|efficient|effort|email|employ|employee|employer|employment|engineer|engineering|equipment|error|essay|estimate|evaluate|exam|examination|examine|example|executive|exercise|experience|experienced|experiment|expert|explain|explanation|export|facility|factory|fail|failure|feedback|file|finance|financial|firm|flexible|focus|form|formal|fund|funding|geography|goal|grade|graduate|hire|homework|import|income|industrial|industry|inform|information|inquiry|institute|institution|instruction|instructor|intelligence|intelligent|interview|invent|invention|invest|investment|IT|job|journal|keyboard|knowledge|lab|labor|laboratory|language|laptop|lead (guide)|leader|leadership|leading|learn|learning|lecture|lesson|letter|level|list|literacy|machine|manage|management|manager|mark|marketing|master|math|mathematics|meaning|measure|measurement|meeting|method|mistake|monitor|multiply|network|note|objective|observation|observe|occupation|office|official|operate|organization|organize|organized|organizer|outline|paper|paragraph|pen|pencil|percent|percentage|physics|plan|planning|position|practical|practice|preparation|prepare|prepared|presentation|primary|principal|print|printer|printing|priority|procedure|process|produce|producer|product|production|profession|professional|professor|profit|program|progress|project|promote|pronounce|proposal|propose|qualification|qualify|question|questionnaire|quit|quote|raise|range|rank|rate|recommend|recommendation|reference|register|reject|report|request|require|requirement|research|researcher|resign|responsibility|responsible|result|retire|retired|review|revise|robot|role|salary|schedule|school|science|scientific|scientist|secondary|secretary|sector|senior|sentence|session|shift|skill|software|solution|solve|specialist|speech|spell|spelling|staff|standard|statistic|strategy|student|study|subject|submit|succeed|success|successful|successfully|sum|summarize|summary|supervisor|survey|system|tablet|target|task|teach|teacher|teaching|team|technical|technique|technology|term|test|text|theory|topic|trade|train|trainer|training|translate|translation|unemployed|unemployment|uniform|union|university|update|user|wage|work|worker|working|word|write|writing"),
            (.nature, "air|animal|atmosphere|autumn|bank (river)|beach|bear (animal)|bee|biology|bird|branch|bush|cat|chemical|climate|cloud|coal|coast|cold|continent|countryside|cow|creature|crop|desert|dig|disaster|dog|dry|dust|earth|earthquake|elephant|energy|environment|environmental|farm|farmer|farming|feather|field|fire|fish|flame|flood|flow|flower|forest|freeze|frog|frozen|fur|garbage|garden|gas|global|gold|grain|grass|green|ground|grow|growth|heat|hill|horse|hot|hunt|hunting|hurricane|ice|insect|island|lake|land|landscape|leaf|lion|metal|melt|mineral|monkey|moon|mount|mountain|mouse|mud|natural|naturally|nature|nuclear|ocean|oil|outdoor|outdoors|pet|phenomenon|pig|planet|plant|plastic|poison|poisonous|pollution|preserve|protect|protection|rabbit|rain|range|recycle|river|rock (stone)|root|rural|sand|sea|season|seed|shade|shadow|sheep|shell|shine|shiny|sky|smoke|snake|snow|soil|solar|space|species|spider|spring|star|stone|storm|stream|summer|sun|sunny|surrounding|tail|temperature|trash|tree|tropical|universe|valley|warm|waste|water|wave|weather|wet|wild|wildlife|wind (moving air)|wing|winter|wood|wooden|world|worldwide"),
            (.society, "accuse|administration|adopt|affair|agency|aid|appeal|approval|approve|armed|arms|army|arrest|association|attack|attorney|authority|ban|barrier|battle|benefit|bomb|border|bullet|campaign|candidate|capital|case|charity|church|citizen|city|civil|claim|command|commission|committee|community|conflict|congress|conservative|control|contribution|council|country|county|court|crime|criminal|crisis|cruel|currency|custom|debate|debt|declare|defend|defense|democracy|demonstrate|detect|detective|district|document|donate|duty|economic|economy|elect|election|emergency|enemy|equal|equally|ethical|evidence|fair|faith|federal|fight|fighting|flag|force|freedom|fund|funding|gang|global|god|govern|government|governor|grant|guard|guilty|gun|heaven|hell|holy|honor|human|identify|identity|illegal|immigrant|independent|innocent|institution|insurance|international|investigate|investigation|issue|judge|judgment|justice|justify|kill|killing|king|law|lawyer|legal|license|lord|majority|mayor|military|minister|minority|moral|murder|nation|national|obey|obligation|offense|officer|official|oppose|opposed|opposition|organization|palace|parliament|peace|peaceful|permission|permit|police|policy|political|politician|politics|poor|population|poverty|power|powerful|pray|prayer|president|priest|prince|princess|prison|prisoner|privacy|private|protest|prove|public|punish|punishment|queen|race|racial|rebel|religion|religious|represent|representative|rescue|resident|responsibility|revolution|rich|right|royal|rule|safety|secure|security|senate|senator|servant|service|slave|social|society|soldier|spiritual|state|statement|status|steal|strike|suspect|tax|thief|threat|threaten|trial|unfair|union|united|victim|violence|violent|volunteer|vote|war|warning|wealth|wealthy|weapon|witness"),
            (.essentials, "ability|able|accept|action|add|advice|advise|agree|allow|answer|appear|apply|arrange|ask|avoid|be|become|begin|believe|belong|borrow|break|bring|build|buy|call|can (modal verb)|cannot|care|carry|catch|change|check|choose|clean|close (shut)|come|compare|complain|complete|consider|continue|cook|could|count|create|cut|decide|describe|die|discuss|do|draw|drink|drive|eat|enjoy|explain|fall|feel|fill|find|finish|fix|follow|forget|forgive|get|give|go|grow|happen|hate|have|have to|hear|help|hold|hope|hurt|improve|include|invite|join|keep|know|learn|leave|lend|let|like (find sb/sth pleasant)|listen|live (reside)|look|lose|love|make|may|mean|meet|might|miss|move|must|need|offer|open|order|own|pay|plan|play|prefer|prepare|promise|put|read|receive|remember|repeat|reply|return|run|save|say|see|seem|sell|send|shall|share|should|show|shut|sing|sit|sleep|speak|spend|stand|start|stay|stop|study|suggest|swim|take|talk|teach|tell|thank|think|throw|travel|try|turn|understand|use|used to|wait|wake|walk|want|wash|watch|wear|will|win|wish|work|worry|would|write|address|age|appointment|bag|bank (money)|bill|book|bus|car|card|cash|city|clothes|coffee|cost|country|date|day|doctor|dollar|door|email|euro|evening|family|food|friend|home|hospital|hotel|hour|house|job|key|language|letter|life|man|meal|message|minute (time)|money|month|morning|name|night|number|o’clock|office|order|paper|phone|place|price|question|reason|room|school|second (unit of time)|shop|street|student|table|teacher|thing|ticket|time|today|tomorrow|town|water|way|week|weekend|woman|word|year|yesterday"),
        ]
        var result: [String: Set<VocabularyTopic>] = [:]
        for (topic, words) in groups {
            for word in words.split(separator: "|") {
                result[String(word).lowercased(), default: []].insert(topic)
            }
        }
        return result
    }()

    // Each entry in the former essentials collection has one explicit core group.
    // Keep these exact headwords case-sensitive: May (month) differs from may (modal).
    private static let coreGroups: [String: VocabularyTopic] = {
        let groups: [(VocabularyTopic, String)] = [
            (.commonVerbs, "adapt|add|alter|appear|apply|arise|arrange|attach|avoid|be|bear (deal with)|become|begin|belong|bend|bite|block|blow|boil|borrow|break|bring|build|bury|buy|capture|carry|cast|catch|cause|change|check|choose|clean|click|climb|close (shut)|collapse|combine|come|commit|complete|conduct|connect|consist|contain|continue|contribute|convert|cook|cost|count|cover|create|cut|deal|decline|decrease|defeat|depend|destroy|die|disappear|discover|display|distribute|divide|do|dominate|download|drag|draw|drink|drive|drop|eat|emerge|empty|enable|encounter|end|engage|enhance|ensure|escape|establish|exist|expand|explode|expose|extend|fall|feed|fill|find|finish|fix|float|follow|found|gain|gather|generate|get|give|go|grab|grow|handle|happen|have|hide|hit|hold|hurt|impose|improve|include|increase|involve|join|keep|knock|last (taking time)|launch|lean|leave|lend|let|limit|link|live (reside)|load|look|lose|lower|maintain|make|meet|mix|modify|move|need|obtain|occur|offer|open|order|pass|pay|pick|place|play|pose|possess|prepare|prevent|provide|pull|pursue|push|put|read|receive|reduce|release|remain|remove|repeat|resist|resolve|retain|return|reveal|rid|ring (sound)|rise|roll|rub|run|rush|satisfy|save|scan|search|seek|select|sell|send|separate|settle|shake|share|shop|show|shut|sing|sit|sleep|slide|slip|slow|sort|spend|split|sponsor|spot|spread|stand|start|stay|step|stick (push into/attach)|stop|study|support|surround|swim|switch|take|tear (rip)|tend|throw|touch|transform|travel|trick|trouble|try|turn|type|urge|use|vary|view|wait|wake|walk|warn|wash|watch|water|wear|win|wind (turn/twist)|work|write"),
            (.communicationVerbs, "abandon|accept|acknowledge|admire|admit|advise|affect|agree|allow|announce|annoy|answer|appreciate|approach|ask|associate|assume|attempt|beg|believe|blame|bother|call|care|chat|cheat|cite|comment|compare|complain|concern|conclude|confirm|confuse|consider|contact|contrast|convince|criticize|decide|demand|deny|describe|deserve|desire|determine|discuss|dislike|doubt|dream|emphasize|encourage|enjoy|excuse|expect|explain|express|favor|feel|figure|forget|forgive|guess|hate|hear|help|hesitate|highlight|hope|ignore|imply|impress|indicate|influence|insist|inspire|intend|interest|interpret|interrupt|invite|know|lack|laugh|learn|lie (tell a lie)|like (find sb/sth pleasant)|listen|love|mean|mention|mind|miss|name|notice|offend|persuade|phone|plan|please|point|praise|predict|prefer|present|pretend|price|promise|question|react|realize|recall|recognize|refer|reflect|refuse|regard|regret|relate|rely|remark|remember|remind|reply|respond|reward|risk|say|scream|see|seem|sense|shout|sign|signal|speak|stare|struggle|suggest|suppose|surprise|swear|talk|teach|tell|thank|think|understand|want|wish|wonder|worry"),
            (.adjectives, "able|absolute|acceptable|active|actual|additional|aggressive|all right|amazed|amazing|annoyed|annoying|apparent|appropriate|artificial|associated|attractive|automatic|average|aware|awesome|awful|bad|based|basic|bent|best|better|big|brief|bright|brilliant|broad|capable|careful|careless|central|certain|characteristic|clear|close (near)|colored|common|complex|complicated|concerned|confused|confusing|connected|consistent|constant|continuous|convenient|convinced|cool|correct|covered|critical|crucial|current|curved|dangerous|dark|decent|deep|definite|deliberate|determined|different|difficult|direct|disappointing|dishonest|double|due|easy|electronic|enormous|enthusiastic|entire|essential|everyday|evil|exact|excellent|exciting|expected|external|extra|extraordinary|extreme|false|familiar|famous|fancy|fantastic|fascinating|fast|favorite|final|fine|fixed|following|former|free|full|fundamental|general|giant|glad|good|grand|grateful|great|hard|heavy|helpful|high|hollow|horrible|huge|ideal|immediate|important|impossible|impressed|impressive|included|incredible|indirect|informal|initial|inner|intended|intense|interested|interesting|internal|involved|junior|large|last (final)|late|latest|light (not heavy)|likely|limited|liquid|little|logical|long|long-term|loose|loud|low|lucky|main|major|massive|matching|material|medium|mild|minor|missing|mixed|modern|multiple|narrow|necessary|negative|new|nice|noisy|normal|numerous|obvious|odd|offensive|OK|old|old-fashioned|ordinary|original|outer|particular|perfect|permanent|plain|pleasant|pleased|pointed|positive|possible|potential|pretty|previous|prime|proper|proud|pure|qualified|quick|quiet|rapid|rare|raw|ready|real|realistic|reasonable|recent|regional|regular|related|relaxing|relevant|reliable|remote|renewable|repeated|rough|routine|safe|same|secret|serious|severe|shallow|sharp|short|significant|silent|silly|silver|similar|simple|slight|small|smooth|soft|solid|special|specific|spoken|square|stable|steady|steep|sticky|strange|strict|stupid|sudden|suitable|sure|surprised|surprising|tall|temporary|terrible|thick|tight|tiny|top|tough|true|typical|ugly|unable|unexpected|unique|unknown|unlikely|unnecessary|unpleasant|unusual|upper|used|useful|usual|various|vast|virtual|visual|vital|whole|wide|willing|wonderful|worse|worst|worth|wrong"),
            (.adverbs, "absolutely|actually|afterward|again|ago|ahead|almost|already|also|always|anymore|anyway|anywhere|apart|apparently|approximately|aside|automatically|away|back|badly|basically|carefully|certainly|clearly|closely|commonly|completely|constantly|correctly|currently|daily|deeply|definitely|deliberately|differently|directly|down|downward|early|easily|else|elsewhere|entirely|especially|even|eventually|ever|everywhere|exactly|extremely|fairly|finally|forever|fortunately|forward|frequently|fully|further|furthermore|generally|gradually|hardly|heavily|here|highly|how|immediately|increasingly|incredibly|indeed|initially|inside|instead|just|largely|later|loudly|mainly|maybe|meanwhile|mostly|nearly|necessarily|never|next|normally|now|nowhere|obviously|occasionally|off|often|once|only|originally|otherwise|out|outside|overall|particularly|partly|perfectly|perhaps|personally|possibly|previously|probably|properly|quickly|quietly|quite|rapidly|rarely|rather|really|recently|regularly|relatively|seriously|significantly|similarly|simply|slightly|slowly|sometimes|somewhat|somewhere|soon|specifically|still|strongly|suddenly|surely|then|there|thus|together|too|totally|truly|typically|ultimately|unfortunately|up|upward|usually|very|widely|yet"),
            (.essentials, "a, an|about|above|according to|across|after|against|ah|all|along|although|among|and|another|any|anybody|anyone|anything|around|as|at|because|because of|before|behind|below|between|beyond|both|but|by|bye|can (modal verb)|cannot|could|despite|during|each|either|enough|every|everybody|everyone|everything|except|few|for|from|goodbye|have to|he|her|hers|herself|hey|him|himself|his|however|I|if|in|including|instead of|into|its|itself|least|less|like (similar)|lot|many|may|me|might|mine (belongs to me)|more|most|much|must|my|myself|neither|nevertheless|next to|no|nobody|none|no one|nor|not|nothing|of|oh|on|onto|or|other|ought|our|ours|ourselves|over|own|per|plenty|plus|several|shall|she|should|since|sir|so|some|somebody|someone|something|sorry|such|than|that|the|their|theirs|them|themselves|therefore|they|this|though|through|throughout|till|to|toward|under|unless|unlike|until|upon|us|used to|we|what|whatever|when|whenever|where|whereas|wherever|whether|which|while|who|whom|whose|why|will|with|within|without|would|wow|yeah|yes|you|your|yours|yourself"),
            (.timeNumbers, "afternoon|age|annual|April|August|billion|black|blue|brown|century|date|day|decade|December|dozen|eight|eighteen|eighty|eleven|evening|February|fifteen|fifth|fifty|first|five|forty|four|fourteen|fourth|frequency|Friday|future|gray|half|hour|hundred|inch|January|July|June|length|March|maximum|May|meter|midnight|million|minimum|minute (time)|moment|Monday|month|morning|night|nine|nineteen|ninety|November|number|o’clock|October|one|orange|pair|past|period|pink|purple|quantity|quarter|red|Saturday|second (next after the first)|second (unit of time)|September|seven|seventeen|seventy|six|sixteen|sixty|Sunday|ten|third|thirteen|thirty|thousand|three|Thursday|time|today|tomorrow|ton|tonight|total|Tuesday|twelve|twenty|twice|two|unit|Wednesday|week|weekend|white|year|yellow|yesterday|zero"),
            (.nouns, "ability|action|addition|address|advice|agreement|alternative|amount|angle|announcement|appointment|area|arrangement|aspect|bag|bank (money)|base|basis|battery|beginning|being|bill|bit|bond|book|bottom|bubble|bunch|bus|button|car|card|cash|center|challenge|chance|choice|circle|circumstance|city|clothes|clue|coffee|color|column|combination|comparison|component|conclusion|condition|confidence|connection|consequence|consideration|content|context|core|country|criticism|curve|danger|decision|depth|description|diary|difference|difficulty|disadvantage|discovery|distribution|division|doctor|dollar|door|edge|effect|element|email|emphasis|ending|enthusiasm|entry|euro|existence|expectation|explosion|expression|extent|fact|factor|family|fan|fault|feature|fellow|finding|flash|food|fortune|friend|front|function|gap|ghost|group|habit|headline|hero|hole|home|hospital|hotel|house|idea|impact|importance|impression|improvement|incident|initiative|insight|instance|intention|job|key|kind (type)|language|laughter|layer|letter|life|line|loss|luck|man|mass|matter|meal|means|message|middle|mine (hole in the ground)|mission|mixture|model|money|movement|needle|net|noise|notion|object|occasion|office|opponent|opportunity|option|origin|outcome|pace|page|panel|paper|part|passage|passion|pattern|perspective|phase|philosophy|phrase|piece|pile|pin|pitch|pleasure|possession|possibility|potato|powder|prediction|presence|principle|problem|profile|proof|prospect|psychologist|psychology|publication|purpose|quotation|race (competition)|race (of people)|racing|reaction|reality|reason|reception|recipe|reduction|refrigerator|regulation|relation|reputation|resource|response|rest (remaining part)|room|rope|row (line)|sample|satellite|scale|school|section|sequence|set (group)|setting|shame|shape|shot|side|silence|similarity|site|situation|slope|smartphone|soul|source|spirit|stick (piece of wood)|street|string|structure|student|stuff|substance|suggestion|supporter|surface|symbol|table|tank|teacher|theme|thing|thinking|thought|ticket|title|tone|tower|town|transition|trend|truth|tube|umbrella|understanding|variety|version|victory|way|woman|word"),
        ]
        var result: [String: VocabularyTopic] = [:]
        for (topic, words) in groups {
            for word in words.split(separator: "|") {
                precondition(result[String(word)] == nil, "Duplicate core vocabulary assignment")
                result[String(word)] = topic
            }
        }
        return result
    }()

    static let themes: [VocabularyTopic] = [.background, .home, .shopping, .culture, .travel, .health, .work, .nature, .society]
    static let coreCollections: [VocabularyTopic] = [.commonVerbs, .communicationVerbs, .adjectives, .adverbs, .essentials, .timeNumbers, .nouns]

    static func topics(for english: String) -> Set<VocabularyTopic> {
        // The Swedish catalog sometimes lists alternatives, e.g. bicycle / bike.
        // Classify the primary headword without changing the displayed source text.
        let headword = english.components(separatedBy: " / ").first ?? english
        var result = headwords[headword.lowercased()] ?? [.essentials]
        if result.remove(.essentials) != nil {
            result.insert(coreGroups[headword] ?? .nouns)
        }
        return result
    }

}

extension VocabularyWord {
    var studyTopics: Set<VocabularyTopic> { VocabularyTopic.topics(for: english) }
    func matchesTopic(_ selection: String?) -> Bool {
        guard let selection else { return true }
        if let topic = VocabularyTopic(rawValue: selection) { return studyTopics.contains(topic) }
        return topic == selection // Preserve legacy callers and saved filters.
    }
}

struct TopicProgress {
    var total = 0
    var known = 0
    var learning = 0
    var fraction: Double { total == 0 ? 0 : Double(known) / Double(total) }
}
