//
//  String+.swift
//  SimpleBlockExample
//
//  Created by hs on 10/29/25.
//

extension String {
  /// 지정한 Grapheme 오프셋부터 문자열 끝까지 잘라 반환하고, 원본에서는 해당 부분을 제거합니다.
  mutating func cutSuffix(fromGrapheme offset: Int) -> String {
    guard offset < count else { return "" }  // 끝이면 비어 있음

    let splitIndex = index(startIndex, offsetBy: offset)

    // Substring은 실제 복사 없이 원본 버퍼를 공유함
    let tail = self[splitIndex...]

    // 원본 문자열에서 tail 제거
    self.removeSubrange(splitIndex...)

    // 복사본을 반환해야 하므로 이때만 실제 메모리 복사 발생
    return String(tail)
  }
}
