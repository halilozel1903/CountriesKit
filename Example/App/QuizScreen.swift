import SwiftUI
import CountriesKit
import CountriesUI

/// "Which country is this flag?" Ten real flags from the API, four names each, wrong answers
/// from the same region. The quiz is seeded: the same flags all day, new ones tomorrow.
struct QuizView: View {
    let scene: ScreenshotScene?
    /// Called with the country of each answered flag (the iPad shows its page next to the quiz).
    var onReveal: (Country) -> Void = { _ in }

    @Environment(Atlas.self) private var atlas
    @State private var seed: UInt64
    @State private var quiz: FlagQuiz?
    @State private var index = 0
    @State private var choices: [Int: Country] = [:]

    init(scene: ScreenshotScene?, onReveal: @escaping (Country) -> Void = { _ in }) {
        self.scene = scene
        self.onReveal = onReveal
        _seed = State(initialValue: scene == .quiz ? ScreenshotScene.quizSeed : Atlas.dailySeed)
    }

    var body: some View {
        Group {
            if let quiz {
                if index < quiz.questions.count {
                    ScrollView {
                        QuestionCard(
                            question: quiz.questions[index],
                            total: quiz.questions.count,
                            score: quiz.score(choices),
                            choice: choices[quiz.questions[index].number],
                            choose: choose,
                            next: { index += 1 }
                        )
                        .padding(16)
                        .frame(maxWidth: 560)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    QuizResult(score: quiz.score(choices), total: quiz.questions.count) {
                        seed &+= 1
                        restart()
                    }
                }
            } else if let error = atlas.quizError {
                LoadErrorView(message: error) {
                    Task { await prepare() }
                }
            } else {
                ProgressView("Picking flags")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.background)
        .task {
            await prepare()
        }
        .signalsScreenshotReady(scene == .quiz ? scene : nil, when: quiz != nil && !choices.isEmpty)
    }

    private func prepare() async {
        await atlas.loadQuiz()
        guard quiz == nil else { return }
        restart()
        // The screenshot shows the first flag answered, so the feedback is visible.
        if scene == .quiz, let first = quiz?.questions.first {
            choose(first.answer)
        }
    }

    private func restart() {
        guard let countries = atlas.quizCountries else { return }
        quiz = FlagQuiz(countries: countries, questionCount: 10, optionCount: 4, seed: seed, independentOnly: true)
        index = 0
        choices = [:]
    }

    private func choose(_ country: Country) {
        guard let quiz, index < quiz.questions.count else { return }
        let question = quiz.questions[index]
        guard choices[question.number] == nil else { return }
        withAnimation(.snappy) {
            choices[question.number] = country
        }
        onReveal(question.answer)
    }
}

/// One flag, four names, and after a choice whether it was right.
struct QuestionCard: View {
    let question: FlagQuiz.Question
    let total: Int
    let score: Int
    let choice: Country?
    let choose: (Country) -> Void
    let next: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Flag " + String(question.number) + " of " + String(total))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.secondary)
                Spacer()
                Label(String(score), systemImage: "star.fill")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(Theme.gold)
            }
            ProgressView(value: Double(question.number - (choice == nil ? 1 : 0)), total: Double(total))
                .tint(Theme.gold)

            FlagImage(url: question.answer.flagURL, emoji: nil, label: "The flag to name", cornerRadius: 12)
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .cardBackground()

            Text("Which country does this flag belong to?")
                .font(.title3.bold())

            VStack(spacing: 10) {
                ForEach(question.options) { option in
                    OptionButton(
                        title: option.commonName,
                        state: state(of: option)
                    ) {
                        choose(option)
                    }
                    .disabled(choice != nil)
                }
            }

            if let choice {
                feedback(correct: question.isCorrect(choice))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func state(of option: Country) -> OptionButton.Mark {
        guard let choice else { return .open }
        if question.isCorrect(option) { return .correct }
        if option.id == choice.id { return .wrong }
        return .dimmed
    }

    private func feedback(correct: Bool) -> some View {
        let answer = question.answer
        let details = [answer.primaryCapital.map { "Capital " + $0 }, answer.subregion, answer.formattedArea(.compact)]
            .compactMap { $0 }
            .joined(separator: " · ")
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: correct ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(correct ? Theme.correct : Theme.wrong)
                VStack(alignment: .leading, spacing: 2) {
                    Text(correct ? "Correct! It's " + answer.commonName + "." : "It's " + answer.commonName + ".")
                        .font(.headline)
                    if !details.isEmpty {
                        Text(details)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
            Button(action: next) {
                Text(question.number < total ? "Next flag" : "See your score")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.ocean)
        }
        .padding(14)
        .cardBackground()
    }
}

/// A name to pick, colored once the answer is known.
struct OptionButton: View {
    enum Mark {
        case open, correct, wrong, dimmed
    }

    let title: String
    let state: Mark
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                switch state {
                case .correct:
                    Image(systemName: "checkmark.circle.fill")
                case .wrong:
                    Image(systemName: "xmark.circle.fill")
                case .open, .dimmed:
                    EmptyView()
                }
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(border, lineWidth: 1.5)
            }
            .opacity(state == .dimmed ? 0.55 : 1)
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        switch state {
        case .correct: return Theme.correct
        case .wrong: return Theme.wrong
        case .open, .dimmed: return Color.primary
        }
    }

    private var background: Color {
        switch state {
        case .correct: return Theme.correct.opacity(0.14)
        case .wrong: return Theme.wrong.opacity(0.14)
        case .open, .dimmed: return Theme.surface
        }
    }

    private var border: Color {
        switch state {
        case .correct: return Theme.correct
        case .wrong: return Theme.wrong
        case .open, .dimmed: return Color.clear
        }
    }
}

/// The end of a round.
struct QuizResult: View {
    let score: Int
    let total: Int
    let playAgain: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(String(score) + " of " + String(total), systemImage: score * 2 >= total ? "trophy.fill" : "flag.fill")
        } description: {
            Text(score == total ? "Every flag right." : "Play another round with new flags.")
        } actions: {
            Button("Play Again", action: playAgain)
                .buttonStyle(.borderedProminent)
                .tint(Theme.ocean)
        }
    }
}

/// iPhone: the quiz in its own tab.
struct QuizScreen: View {
    let scene: ScreenshotScene?

    var body: some View {
        NavigationStack {
            QuizView(scene: scene)
                .navigationTitle("Flag Quiz")
                .navigationBarTitleDisplayMode(.inline)
                .atlasNavigationBar()
        }
    }
}
