import Foundation
import Testing
@testable import CountriesKit

@Suite("Flag quiz")
struct QuizTests {
    private func countries() throws -> [Country] {
        try Fixture.decode([Country].self, from: "all-quiz")
    }

    @Test func splitMix64() {
        var generator = SeededGenerator(seed: 0)
        let first = generator.next()
        let second = generator.next()

        #expect(first == 0xE220_A839_7B1D_CDAF)
        #expect(second == 0x6E78_9E6A_A1B9_65F4)
    }

    @Test func seededShuffleIsRepeatable() {
        var one = SeededGenerator(seed: 42)
        var two = SeededGenerator(seed: 42)
        let a = one.shuffled(Array(0..<20))
        let b = two.shuffled(Array(0..<20))

        #expect(a == b)
        #expect(a.sorted() == Array(0..<20))
        #expect(a != Array(0..<20))
    }

    @Test func sameSeedSameQuiz() throws {
        let pool = try countries()
        let first = FlagQuiz(countries: pool, seed: 2026)
        let second = FlagQuiz(countries: pool.reversed(), seed: 2026)
        let other = FlagQuiz(countries: pool, seed: 7)

        #expect(first == second)
        #expect(first.questions.map(\.answer.id) != other.questions.map(\.answer.id))
    }

    @Test func questionsAreWellFormed() throws {
        let quiz = FlagQuiz(countries: try countries(), questionCount: 10, optionCount: 4, seed: 2026)

        #expect(quiz.questions.count == 10)
        #expect(Set(quiz.questions.map(\.answer.id)).count == 10)
        #expect(quiz.questions.map(\.number) == Array(1...10))
        for question in quiz.questions {
            #expect(question.options.count == 4)
            #expect(Set(question.options.map(\.id)).count == 4)
            #expect(question.options[question.correctIndex].id == question.answer.id)
            #expect(question.isCorrect(question.answer))
            #expect(question.answer.flagURL != nil)
        }
    }

    @Test func wrongAnswersComeFromTheSameRegion() throws {
        let pool = try countries()
        let quiz = FlagQuiz(countries: pool, questionCount: 19, seed: 99)

        for question in quiz.questions where question.answer.region == "Europe" || question.answer.region == "Asia" {
            #expect(question.options.allSatisfy { $0.region == question.answer.region })
        }
        let mixed = FlagQuiz(countries: pool, questionCount: 19, seed: 99, sameRegionOptions: false)
        #expect(mixed.questions.count == 19)
    }

    @Test func ineligibleCountriesAreLeftOut() throws {
        let pool = try countries()
        let eligible = FlagQuiz.eligible(pool + pool)

        #expect(eligible.count == 19)
        #expect(!eligible.contains { $0.id == "XXX" })
        #expect(eligible.map(\.id) == eligible.map(\.id).sorted())

        let independent = FlagQuiz(countries: pool, questionCount: 50, seed: 1, independentOnly: true)
        #expect(independent.questions.count == 18)
        #expect(!independent.questions.contains { $0.answer.id == "ALA" })
    }

    @Test func smallPools() {
        let one = [Country(name: CountryName(common: "Only", official: "Only"), cca3: "ONE", flags: ImageLinks(png: URL(string: "https://flagcdn.com/w320/on.png")))]
        #expect(FlagQuiz(countries: one, seed: 1).questions.isEmpty)
        #expect(FlagQuiz(countries: [], seed: 1).questions.isEmpty)

        let two = one + [Country(name: CountryName(common: "Other", official: "Other"), cca3: "TWO", flags: ImageLinks(png: URL(string: "https://flagcdn.com/w320/tw.png")))]
        let quiz = FlagQuiz(countries: two, questionCount: 5, optionCount: 4, seed: 1)
        #expect(quiz.questions.count == 2)
        #expect(quiz.questions.allSatisfy { $0.options.count == 2 })
    }

    @Test func scoring() throws {
        let quiz = FlagQuiz(countries: try countries(), questionCount: 3, seed: 5)
        var choices: [Int: Country] = [:]
        for question in quiz.questions {
            choices[question.number] = question.answer
        }
        let wrong = try #require(quiz.questions.last?.options.first { $0.id != quiz.questions.last?.answer.id })
        choices[3] = wrong

        #expect(quiz.score(choices) == 2)
        #expect(quiz.score([:]) == 0)
    }
}
