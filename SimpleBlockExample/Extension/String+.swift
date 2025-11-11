//
//  String+.swift
//  SimpleBlockExample
//
//  Created by hs on 10/29/25.
//

extension String {
  mutating func cutSuffix(fromGrapheme offset: Int) -> String {
    guard offset < count else { return "" }  // 끝이면 비어 있음

    let i = index(startIndex, offsetBy: offset)

    // Substring은 실제 복사 없이 원본 버퍼를 공유함
    let tail = self[i...]

    // 원본 문자열에서 tail 제거
    self.removeSubrange(i...)

    // 복사본을 반환해야 하므로 이때만 실제 메모리 복사 발생
    return String(tail)
  }
}
