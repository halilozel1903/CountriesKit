import Foundation

/// A small, seedable random number generator (SplitMix64). The same seed gives the same numbers
/// on every device and Swift version, so a quiz can be repeated, shared as a "daily seed" or
/// tested.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A number in `0..<bound`. Unlike `Int.random(in:using:)`, the algorithm is fixed here, so
    /// results never change with the standard library.
    public mutating func next(below bound: Int) -> Int {
        precondition(bound > 0, "bound must be positive")
        return Int(next() % UInt64(bound))
    }

    /// `elements` in a seeded order (Fisher–Yates).
    public mutating func shuffled<Element>(_ elements: [Element]) -> [Element] {
        var result = elements
        var index = result.count - 1
        while index > 0 {
            let other = next(below: index + 1)
            result.swapAt(index, other)
            index -= 1
        }
        return result
    }
}

/// A "which country is this flag?" quiz built from real countries.
///
/// The same countries and seed always give the same questions and the same option order, so a
/// quiz can be replayed, offered as a daily challenge (seed it with the date) or tested.
///
/// ```swift
/// let countries = try await api.all()
/// let quiz = FlagQuiz(countries: countries, questionCount: 10, seed: 2026)
/// let first = quiz.questions[0]
/// first.answer.flagURL           // the flag to show
/// first.options.map(\.commonName) // four names, one of them right
/// first.isCorrect(first.options[2])
/// ```
public struct FlagQuiz: Hashable, Sendable {
    /// One flag and the names to choose from.
    public struct Question: Identifiable, Hashable, Sendable {
        /// 1 for the first question.
        public let number: Int
        /// The country whose flag is shown.
        public let answer: Country
        /// The choices, the answer among them.
        public let options: [Country]

        public var id: Int { number }

        /// Where the answer is in ``options``.
        public var correctIndex: Int {
            options.firstIndex { $0.id == answer.id } ?? 0
        }

        /// Whether `choice` is the answer.
        public func isCorrect(_ choice: Country) -> Bool {
            choice.id == answer.id
        }
    }

    /// The seed the quiz was made with.
    public let seed: UInt64
    public let questions: [Question]

    /// Makes a quiz.
    ///
    /// - Parameters:
    ///   - countries: The countries to ask about; each needs a name and a `cca2` code for its
    ///     flag PNG, as every country of ``CountriesClient/all()`` has.
    ///   - questionCount: Questions to ask; fewer when there are fewer countries.
    ///   - optionCount: Choices per question, the answer included (at least 2).
    ///   - seed: The seed for the order of questions and options.
    ///   - independentOnly: Leave out territories (countries whose `independent` is not `true`).
    ///   - sameRegionOptions: Prefer wrong answers from the answer's region, which makes the quiz
    ///     harder (Chad or Romania?).
    public init(
        countries: [Country],
        questionCount: Int = 10,
        optionCount: Int = 4,
        seed: UInt64,
        independentOnly: Bool = false,
        sameRegionOptions: Bool = true
    ) {
        self.seed = seed
        var pool = FlagQuiz.eligible(countries)
        if independentOnly {
            pool = pool.filter { $0.independent == true }
        }
        guard pool.count >= 2, questionCount > 0 else {
            questions = []
            return
        }
        let optionCount = max(2, min(optionCount, pool.count))
        var generator = SeededGenerator(seed: seed)
        let answers = generator.shuffled(pool).prefix(min(questionCount, pool.count))

        var made: [Question] = []
        for (offset, answer) in answers.enumerated() {
            let others = pool.filter { $0.id != answer.id }
            var distractors: [Country] = []
            if sameRegionOptions, let region = answer.region {
                distractors = generator.shuffled(others.filter { $0.region == region })
            }
            if distractors.count < optionCount - 1 {
                let chosen = Set(distractors.map(\.id))
                distractors += generator.shuffled(others.filter { !chosen.contains($0.id) })
            }
            let options = generator.shuffled(Array(distractors.prefix(optionCount - 1)) + [answer])
            made.append(Question(number: offset + 1, answer: answer, options: options))
        }
        questions = made
    }

    /// The countries a quiz can use: with a name and a flag PNG, one per id, sorted by id so the
    /// order they were loaded in does not change the quiz.
    public static func eligible(_ countries: [Country]) -> [Country] {
        var seen = Set<String>()
        return countries
            .filter { $0.name != nil && $0.flagURL != nil && !$0.id.isEmpty }
            .sorted { $0.id < $1.id }
            .filter { seen.insert($0.id).inserted }
    }

    /// The number of right answers in `choices`, by question number.
    public func score(_ choices: [Int: Country]) -> Int {
        questions.reduce(0) { total, question in
            guard let choice = choices[question.number] else { return total }
            return question.isCorrect(choice) ? total + 1 : total
        }
    }
}
