//
//  Debouncer.swift
//  SimpleBlockExample
//
//  Created by hs on 11/4/25.
//

actor Debouncer {
	private var task: Task<Void, Never>?
	
	func scheduleOnMain(delay: Duration = .nanoseconds(1_000_000_000),
											action: @MainActor @Sendable @escaping () -> Void) {
		task?.cancel()
		task = Task {
			do { try await Task.sleep(for: delay) } catch { return }
			// MainActor에서 실행
			await action()
		}
	}
	
	func cancel() {
		task?.cancel()
		task = nil
	}
	
	deinit { task?.cancel() }
}
