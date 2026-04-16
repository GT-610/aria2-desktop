abstract final class GithubIds {
  static const contributors = <GhId>{};

  static const participants = <GhId>{};
}

typedef GhId = String;

extension GhIdX on GhId {
  String get url => 'https://github.com/$this';

  String get markdownLink => '[$this]($url)';
}
