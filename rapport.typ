#import "@preview/ilm:1.4.1": *
#import "@preview/gentle-clues:1.2.0": *
#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.8": *

#show: ilm.with(
  title: [Rapport Labo 2],
  author: "Kenan Augsburger",
  date: datetime.today(),
  paper-size: "a4",
  date-format: "[day padding:zero] [month repr:long] [year repr:full]",
)

#set page(numbering: "1")
#set text(lang: "fr")

#codly(
  languages: (
    pseudocode: (
      name: "pseudocode",
      icon: text(font: "JetBrainsMono NFP", "ⓟ "),
      color: rgb("#89caff"),
    ),
  ),
)

#show: codly-init.with()
#codly(languages: codly-languages)

#show link: underline
#show raw: set text(font: "JetBrainsMono NFP")

#let _red(x) = text(
  fill: color.red,
  $#x$,
)

