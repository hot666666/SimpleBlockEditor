//
//  Debouncer.swift
//  SimpleBlockExample
//
//  Created by hs on 11/4/25.
//

/// 기존 작업이 있으면 취소하고, 지정한 지연 후 새 작업을 실행하는 debouncer.
/// 주로 빠르게 반복 호출되는 이벤트를 일정 시간 후 한 번만 처리할 때 사용.
actor Debouncer {
  private var task: Task<Void, Never>?

  func updateScheduleOnMain(
    delay: Duration = .nanoseconds(1_000_000_000),
    action: @MainActor @Sendable @escaping () -> Void
  ) {
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
