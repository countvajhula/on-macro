#lang info

(define version "5.0")
(define collection "qi")
(define deps '("base"))
(define build-deps '("scribble-lib"
                     "scribble-abbrevs"
                     "scribble-math"
                     "racket-doc"
                     "sandbox-lib"
                     "metapict"
                     "qi-lib"
                     "qi-probe"))
(define scribblings '(("scribblings/qi.scrbl" (multi-page) (language))))
(define clean '("compiled" "doc" "doc/qi"))
