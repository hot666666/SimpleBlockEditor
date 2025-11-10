//
//  Debouncer.swift
//  SimpleBlockExample
//
//  Created by hs on 11/4/25.
//

actor Debouncer {
	private var task: Task<Void, Never>?
	
	// 이미 스케줄된 작업이 있으면 취소하고 새로 스케줄
	func updateScheduleOnMain(delay: Duration = .nanoseconds(1_000_000_000),
											action: @MainActor @Sendable @escaping () -> Void) {
		task?.cancel()
		task = Task {
			do { try await Task.sleep(for: delay) } catch { return }
			/// MainActor에서 실행
			await action()
		}
	}
	
	func cancel() {
		task?.cancel()
		task = nil
	}
	
	deinit { task?.cancel() }
}
