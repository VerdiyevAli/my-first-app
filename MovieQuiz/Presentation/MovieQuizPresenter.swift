import UIKit

final class MovieQuizPresenter: MovieQuizPresenterProtocol {
    
    let questionsAmount: Int = 10
    private var currentQuestionIndex: Int = 0
    private var correctAnswers = 0
    var currentQuestion: QuizQuestion?
    var questionFactory: QuestionFactoryProtocol?
    private var statisticService: StatisticServiceProtocol = StatisticService()
    weak var viewController: MovieQuizViewControllerProtocol?
    
    
    func restartGame() {
        currentQuestionIndex = 0
        correctAnswers = 0
        questionFactory?.requestNextQuestion()
        
        // Разблокируем кнопки при перезапуске игры
        viewController?.changeStateButton(isEnabled: true)
    }
    
    func convert(model: QuizQuestion) -> QuizStepViewModel {
        let questionStep = QuizStepViewModel(
            image: UIImage(data: model.image) ?? UIImage(),
            question: model.text,
            questionNumber: "\(currentQuestionIndex + 1)/\(questionsAmount)"
        )
        return questionStep
    }
    
    func isLastQuestion() -> Bool {
        currentQuestionIndex == questionsAmount - 1
    }
    
    func switchToNextQuestion() {
        currentQuestionIndex += 1
    }
    
    private func didAnswer(isYes: Bool) {
        guard let currentQuestion = currentQuestion else {
            return
        }
        
        let givenAnswer = isYes
        viewController?.showAnswerResult(isCorrect: givenAnswer == currentQuestion.correctAnswer)
    }
    
    func yesButtonClicked() {
        didAnswer(isYes: true)
    }
    
    func noButtonClicked() {
        didAnswer(isYes: false)
    }
    
    func didRecieveNextQuestion(question: QuizQuestion?) {
        guard let question = question else {
            return
        }
        
        currentQuestion = question
        let viewModel = convert(model: question)
        
        DispatchQueue.main.async { [weak self] in
            self?.viewController?.show(quiz: viewModel)
            
            // Задержка в 1 секунду перед разблокировкой кнопки
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.viewController?.changeStateButton(isEnabled: true)
            }
        }
    }
    
    func showCurrentQuestion() {
        questionFactory?.requestNextQuestion()
    }
    
    private func createResultModel() -> QuizResultsViewModel {
        let text = correctAnswers == self.questionsAmount ?
        "Поздравляем, вы ответили на 10 из 10" :
        "Ваш результат \(correctAnswers) из 10"
        
        return QuizResultsViewModel(
            title: "Этот раунд окончен",
            text: text,
            buttonText: "Сыграть еще раз"
        )
    }
    
    func showAnswerResult(isCorrect: Bool) {
        if isCorrect {
            self.correctAnswers += 1
        }
        
        // Блокируем кнопки сразу после ответа
        viewController?.highlightImageBorder(isCorrect: isCorrect)
        viewController?.changeStateButton(isEnabled: false)  // Блокируем кнопку после ответа
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.showNextQuestionOrResults()
        }
    }
    
    func showNextQuestionOrResults() {
        if self.isLastQuestion() {
            let resultModel = createResultModel()
            
            statisticService.store(correct: correctAnswers, total: self.questionsAmount)
            
            let gamesPlayed = statisticService.gamesCount
            let bestGame = statisticService.bestGame
            let highestCorrect = statisticService.highestCorrect
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd.MM.yy HH:mm"
            let formattedDate = dateFormatter.string(from: bestGame.date)
            
            let message = """
                \(resultModel.text)
                Количество сыгранных квизов: \(gamesPlayed)
                Рекорд: \(highestCorrect)/10 (\(formattedDate))
                Средняя точность: \(String(format: "%.2f", statisticService.totalAccuracy))%
                """
            
            let alertModel = AlertModel(
                title: "Этот раунд окончен",
                message: message,
                buttonText: resultModel.buttonText
            ) { [weak self] in
                guard let self = self else { return }
                
                self.restartGame()
            }
            
            viewController?.showAlert(model: alertModel)
            
        } else {
            self.switchToNextQuestion()
            showCurrentQuestion()
        }
    }
}