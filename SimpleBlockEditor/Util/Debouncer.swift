//
//  Debouncer.swift
//  SimpleBlockEditor
//
//  Created by hs on 11/4/25.
//

/// 기존 작업을 취소하고 일정 지연 뒤 최신 작업만 실행하는 비동기 디바운서입니다.
actor Debouncer {
  /// 현재 예약된 지연 작업입니다.
  private var task: Task<Void, Never>?

  /// 새 동작을 MainActor에서 지연 실행하도록 등록합니다.
  func updateScheduleOnMain(
    delay: Duration = .nanoseconds(1_000_000_000),
    action: @MainActor @Sendable @escaping () -> Void
  ) {
    task?.cancel()
    task = Task {
      do { try await Task.sleep(for: delay) } catch { return }
      await action()
    }
  }

  /// 예약된 작업을 취소하고 내부 상태를 비웁니다.
  func cancel() {
    task?.cancel()
    task = nil
  }

  deinit { task?.cancel() }
}
