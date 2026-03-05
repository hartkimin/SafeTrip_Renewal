/// MOFA API HTML 응답에서 flutter_html 렌더링 오류를 유발하는
/// style 속성을 제거하는 유틸리티.
///
/// 외교부 API가 반환하는 HTML에 font-feature-settings, font-variant 등
/// Flutter의 FontFeature가 처리하지 못하는 CSS가 포함되어
/// 'Feature tag must be exactly four characters long' assertion 발생.
String sanitizeHtml(String html) {
  // style="..." 속성 전체 제거
  return html.replaceAll(RegExp(r'\s*style="[^"]*"', caseSensitive: false), '');
}
