#lang scribble/doc
@require[scribble/manual
         scribble-abbrevs/manual
         scribble/example
         "eval.rkt"
         @for-label[qi
                    racket]]

@(define eval-for-docs (make-eval-for-docs))

@title{Introduction and Usage}

@table-of-contents[]

@section{Overview}

One way to structure computations -- the one we typically employ when writing functions in Racket or another programming language -- is as a flowchart, with arrows representing transitions of control, indicating the sequence in which actions are performed. Aside from the implied ordering, the actions are independent of one another and could be anything at all. Another way -- provided by the present module -- is to structure computations as a fluid flow, like a flow of energy, electricity passing through a circuit, streams flowing around rocks. Here, arrows represent that actions feed into one another.

The former way is often necessary when writing functions at a low level, where the devil is in the details. But once these functional building blocks are available, the latter model is often more appropriate, allowing us to compose functions at a high level to derive complex and robust functional pipelines from simple components with a minimum of repetition and boilerplate, engendering @hyperlink["https://www.theschooloflife.com/thebookoflife/wu-wei-doing-nothing/"]{effortless clarity}.

Here are some examples of computing with Qi using @tech{flows}:

@examples[
    #:eval eval-for-docs
    #:label #f
    (require qi)
    (map (☯ (~> sqr add1)) (list 1 2 3))
    (filter (☯ (< 5 _ 10)) (list 3 7 9 12))
    (~> (3 4) (>< sqr) +)
    (switch (2 3)
      [> -]
      [< +])
    (define-flow root-mean-square
      (~> △ (>< sqr) (-< + count) / sqrt))
    (root-mean-square (range 10))
  ]

Qi is especially useful for expressing computations in a functional, immutable style, and embedding such computations anywhere in the source program, and when working with @seclink["values-model" #:doc '(lib "scribblings/reference/reference.scrbl")]{multiple values}.

@examples[
    #:eval eval-for-docs
    (require qi racket/list)
    (define-flow (list-insert xs i v)
      (~> (group 2 split-at list)
          (select 1 3 2) append))
    (split-at '(a b d) 2)
    (list-insert '(a b d) 2 'c)
  ]

@section{Installation}

Qi is a hosted language on the @hyperlink["https://racket-lang.org/"]{Racket platform}. If you don't already have Racket installed, you will need to @hyperlink["https://download.racket-lang.org/"]{install it}. Then, install Qi at the command line using:

@codeblock{
    raco pkg install qi
}

 Qi is designed to be used in tandem with a host language, such as Racket itself. To use it in a Racket module, simply @racket[(require qi)].

@section{Using Qi}

 Qi may be used in normal (e.g. Racket) code by employing an appropriate @seclink["Language_Interface"]{interface} form. These forms embed the Qi language into the host language, that is, they allow you to use Qi anywhere in your program, and provide shorthands for common cases.

 Since some of the forms use and favor unicode characters (while also providing plain-English aliases), see @secref["Flowing_with_the_Flow"] for tips on entering these characters. Otherwise, if you're all set, head on over to the @seclink["Tutorial"]{tutorial}.

@section{Using Qi as a Dependency}

 Qi follows the @hyperlink["https://countvajhula.com/2022/02/22/how-to-organize-your-racket-library/"]{composable package organization scheme}, so that you typically only need to depend on @code{qi-lib} in your @seclink["metadata" #:doc '(lib "pkg/scribblings/pkg.scrbl")]{application or library}. The @code{qi-lib} package entails just those dependencies used in the Qi language itself, rather than those used in tests, benchmarking, documentation, etc. All of those dependencies are encapsulated in separate packages such as @code{qi-test}, @code{qi-doc}, @code{qi-sdk}, and more. This ensures that using Qi as a dependency contributes minimal overhead to your build times.

 Additionally, Qi itself uses few and carefully benchmarked dependencies, so that the load-time overhead of @racket[(require qi)] is minimal.

@section{Relationship to the Threading Macro}

The usual threading macro in @seclink["top" #:indirect? #t #:doc '(lib "scribblings/threading.scrbl")]{Threading Macros} is a purely syntactic transformation that does not make any assumptions about the expressions being threaded through, so that it works out of the box for threading values through both functions as well as macros. On the other hand, Qi is primarily oriented around @emph{functions}, and @tech{flows} are expected to be @seclink["What_is_a_Flow_"]{function-valued}. Threading values through macros using Qi requires special handling.

In the most common case where you are threading functions, Qi's threading form @racket[~>] is a more general version, and almost drop-in alternative, to the usual threading macro. You might consider migrating to Qi if you need to thread more than one argument or would like to make more pervasive use of flow-oriented reasoning. To do so, the only change that would be needed is to wrap the input argument in parentheses. This is necessary in order to be unambiguous since Qi's threading form can thread more than one argument.

For macros, we cannot use them naively as @tech{flows} because macros expect all of their "arguments" to be provided syntactically at compile time -- meaning that the number of arguments must be known at compile time. This is not in general possible with Qi since @tech{flows} may consume and produce an arbitrary number of values, and this number is only determined at runtime. Depending on what you are trying to do, however, there are many ways in which you still can @seclink["Converting_a_Macro_to_a_Flow"]{treat macros as flows in Qi} -- from simple escapes into Racket to more structured approaches including @seclink["Qi_Dialect_Interop"]{writing a Qi dialect}.

For the same reason, Qi also does not interoperate easily with Typed Racket as the type system cannot easily express variadic composition, whereas the threading macro steers clear of this and could be used with Typed Racket without issue.

The threading library also provides numerous shorthands for common cases, many of which don't have equivalents in Qi -- if you'd like to have these, please @hyperlink["https://github.com/drym-org/qi/issues/"]{create an issue} on the source repo to register your interest.

Finally, by virtue of having an @seclink["It_s_Languages_All_the_Way_Down"]{optimizing compiler}, Qi also offers performance benefits in some cases, including for use of sequences of standard functional operations on lists like @racket[map] and @racket[filter], which in Qi @seclink["Don_t_Stop_Me_Now"]{avoid constructing intermediate representations} along the way to generating the final result.

@close-eval[eval-for-docs]
@(set! eval-for-docs #f)
