#lang scribble/doc
@require[scribble/manual
         scribble-abbrevs/manual
         scribble/example
         racket/sandbox
         @for-label[qi
                    qi/probe
                    racket]]

@(define eval-for-docs
  ;; The "trusted" sandbox configuration is needed possibly
  ;; because of the interaction of binding spaces with
  ;; sandbox evaluator. For more context, see the Qi wiki
  ;; "Qi Compiler Sync Sept 2 2022."
  (call-with-trusted-sandbox-configuration
   (lambda ()
     (parameterize ([sandbox-output 'string]
                    [sandbox-error-output 'string]
                    [sandbox-memory-limit #f])
       (make-evaluator 'racket/base
                       '(require qi
                                 qi/probe
                                 (only-in racket/list range)
                                 racket/string
                                 (for-syntax syntax/parse
                                             racket/base))
                       '(define (sqr x)
                          (* x x)))))))

@title{Field Guide}

This section contains practical advice on using Qi. It includes recipes for doing various things, advice on gotchas, troubleshooting commonly encountered errors, and other tips you may find useful "in the field."

@table-of-contents[]

@section{Writing Flows}

@subsection{Start by Drawing a Circuit Diagram}

Before you write a flow, consider drawing out a "circuit diagram" on paper. Start by drawing wires corresponding to the inputs, and then draw boxes for each transformation and trace out what happens to the outputs. This practice is the Qi equivalent of writing "pseudocode" with other languages, and is especially useful when writing complex flows entailing folds and loops. With practice, this can become second nature and can be a very helpful recourse.

@subsection{Use Small Building Blocks}

Decompose your flow into its smallest components, and name each so that they are independent flows. Qi flows, by virtue of being functions, are highly composable, and are, by the same token, eminently decomposable. This tends to make refactoring flows a much more reliable undertaking than it typically is in other languages.

@subsection{Carry Your Toolbox}

A journeyman of one's craft -- a woodworker, electrician, or a plumber, say -- always goes to work with a trusty toolbox that contains the tools of the trade, some perhaps even of their own design. An electrician, for instance, may have a voltage tester, a multimeter, and a continuity tester in her toolbox. Although these are "debugging" tools, they aren't just for identifying bugs -- by providing rapid feedback, they enable her to explore and find creative solutions quickly and reliably. It's the same with Qi. Learn to use the @seclink["Debugging"]{debugging tools}, and use them often.

@section{Debugging}

There are three prominent debugging strategies which may be used independently or in tandem -- @seclink["Using_Side_Effects"]{side effects}, @seclink["Using_a_Probe"]{probing}, and @seclink["Using_Fixtures"]{fixtures}.

@subsection{Using Side Effects}

The most lightweight way to debug your code is to use side effects, as this allows you to check values at various points in flows without affecting their functioning in any way. You can use this debugging approach always, even in functional Racket code that isn't using Qi.

This approach involves using the side-effect form, @racket[effect] (or @racket[ε]) at a particular point (or several points) in the flow in order to see or manipulate the values there. To use it in general Racket code, just wrap the Racket code with @racket[☯] to employ Qi there (and therefore side effects).

Side effects are a natural fit for debugging functional code in general, as the example below shows.

@bold{Example}: Racket's @racket[regexp-replace*] function transforms a string into another based on a regex-based replacement rule. It accepts a pattern, a string, and a replacement rule (as a function), and then constructs the output string by parsing the input string and calling your replacement rule function each time there is a match to the pattern. With regexes, things don't usually work until you've gone through multiple cycles of debugging, so in this case, in order to see what arguments are being supplied to your replacement rule function, you could simply add a side effect using Qi.

@codeblock{
  (regexp-replace* PATTERN
                   str
                   (☯ (ε (>< println) replace-rule)))
}

@subsection{Using a Probe}

@defmodule[qi/probe]

Qi includes a "circuit tester" style debugger, which you can use to check the values at arbitrary points in the flow. It can be used even if the flow is raising an error – the tester can help you find the error. It offers similar functionality to @seclink["top" #:indirect? #t #:doc '(lib "debug/scribblings/debug.scrbl")]{debug} but is specialized for functional debugging and Qi flows.

To use it, first wrap the entire expression @emph{invoking} the flow with a @racket[probe] form. Then, you can place a literal @racket[readout] anywhere within the flow definition to cause the entire expression to evaluate to the values flowing at that point. This works even if your flow is defined elsewhere (even in another file) and only @emph{used} at the invocation site by name.

@deftogether[(
  @defform[(probe flo)]
  @defidform[readout]
)]{
  @racket[probe] simply marks a flow invocation for debugging, and does not change its functionality. Then, when evaluation encounters the first occurrence of @racket[readout] within @racket[flo], the values at that point are immediately returned as the value of the entire @racket[flo]. This is done via a @tech/reference{continuation}, so that you may precede it with whatever flows you like that might help you understand what's happening at that point, and you don't have to worry about it affecting downstream flows during the process of debugging since those flows would simply never be hit. Additionally, readouts may be placed @emph{anywhere} within the flow, and not necessarily on the main stream -- it will always return the values observed at the specific point where you place the readout.

  Note that @racket[probe] is a Racket (rather than Qi) form, and it must wrap a flow @emph{invocation} rather than a flow @emph{definition}. The @racket[readout], on the other hand, is a Qi expression and must be placed somewhere within the flow @emph{definition}.

@racketblock[
    (~> (5) sqr (* 2) add1)
    (probe (~> (5) readout sqr (* 2) add1))
    (probe (~> (5) sqr readout (* 2) add1))
    (probe (~> (5) sqr (* 2) readout add1))
    (probe (~> (5) sqr (* 2) add1 readout))
    (probe (~> (5) sqr (if (~> (> 20) readout) _ (* 2)) add1))
    (define-flow my-flow
      (~> sqr readout (* 3) add1))
    (probe (my-flow 5))
  ]
}

@deftogether[(
  @defform[(qi:probe flo)]
  @defform[(define-probed-flow name body ...)]
  @defform[#:link-target? #f
           (define-probed-flow (name arg ...) body ...)]
)]{

@bold{NOTE}: This way to place readouts in the flow definition is intended for use in @bold{legacy versions of Racket only}, that is, versions 8.2 or earlier. @racket[qi:probe] and @racket[define-probed-flow] are @bold{no longer needed} in Qi (as of Racket 8.3). These forms should be considered @bold{deprecated} on versions 8.3 or later. On these recent versions of Racket, there is no difference in usage between inline and nonlocal flow definitions, and the @racket[readout] may simply be placed wherever you want it. The legacy documentation follows.

  When the flow you'd like to debug is a named flow that is not defined inline at the invocation site, you'll need to take some extra steps to ensure that you can place a @racket[readout] at the @emph{definition} site even though the @racket[probe] itself is placed at the @emph{invocation} site.

  To do this, either wrap the entire body of the definition, or a subflow in the definition, with @racket[qi:probe], or alternatively, use @racket[define-probed-flow] instead of @racket[define-flow], which transparently does this for you. Now, you can place a (distinct) @racket[probe] at the invocation site, as usual, and it will receive the readout that you indicate at the definition site.

  @racket[(define-probed-flow name body)] is equivalent to @racket[(define-flow name (qi:probe body))] or @racket[(define name (flow (qi:probe body)))].

@racketblock[
    (define-probed-flow my-flow
      (~> sqr readout (* 3) add1))
    (probe (my-flow 5))
    (define my-flow-too
      (☯ (qi:probe (~> sqr readout (* 3) add1))))
    (probe (my-flow-too 5))
  ]
}

@subsection{Using Fixtures}

The @seclink["Using_a_Probe"]{probe debugger} allows you to check values at specific points in the flow, that is, essentially, the @emph{output} of the upstream components at that point. It is sometimes also useful to fix the @emph{input} to downstream components. In unit testing, fixing inputs to functions to test their behavior in a known environment is referred to as writing "fixtures." It's the same idea.

The basic way to do it is to insert a @racket[gen] form at the point of interest in the flow, as @racket[gen] ignores its inputs and just produces whatever values you specify.

@racketblock[
  (~> (2) sqr (gen 9) add1 (* 2))
]

Methodical use of @racket[gen] together with the @seclink["Using_a_Probe"]{probe debugger} allows you to isolate bugs to specific sections of the flow, and then triangulate further using the same approach until you find the exact problem.

@racketblock[
  (probe (~> (3) (-< _ "5") (gen 3 5) + sqr readout (* 2) add1))
]

@subsection{Common Errors and What They Mean}

@subsubsection{Expected Number of Values Not Received}

@codeblock{
; result arity mismatch;
;  expected number of values not received
;   expected: 1
;   received: 2
}

@bold{Meaning}: A flow is either returning more or fewer values than the @tech/reference{continuation} of the flow is expecting. See @secref["values-model" #:doc '(lib "scribblings/reference/reference.scrbl")] for general information about this.

@bold{Common example}: Attempting to assign the result of a multi-valued flow to a single variable. Use @racket[define-values] instead of @racket[define] here, or consider decomposing the flow into multiple flows that each return a single value.

@bold{Common example}: Attempting to invoke a function with arguments produced by a multi-valued flow, something like @racket[(+ (~> ((range 10)) △))]. Function application syntax in Racket expects a single argument in each argument position, and cannot receive them all from a flow in this way. You could use @racket[call-with-values] to do it, but it is much simpler to just use Qi's invocation syntax via a threading form, e.g. @racket[(~> ((range 10)) △ +)].

@bold{Common example}: Attempting to employ a @emph{Racket} expression producing multiple values in an expression where the @tech/reference{continuation} expects one value, e.g. @racket[(~> () (gen (values 1 2 3)) +)]. Whether the expression is Racket or Qi, the number of values returned must be the number of values expected by the continuation -- and typically, that's @seclink["values-model" #:doc '(lib "scribblings/reference/reference.scrbl")]{one}. In this example, you could simply write the values directly as separate expressions, each producing one value, e.g. @racket[(~> (1 2 3) +)] or @racket[(~> () (gen 1 2 3) +)]. If you must use a single Racket expression to produce the values, then you could use @racket[(~> () (esc (λ _ (values 1 2 3))) +)], instead.

@bold{Common example}: Using the threading form @racket[~>] without wrapping the input arguments in parentheses. Remember that, unlike Racket's usual threading macro, input arguments to Qi's threading form @seclink["Relationship_to_the_Threading_Macro"]{must be wrapped in parentheses}.

@subsubsection{Wildcard Not Allowed as an Expression}

@codeblock{
;  _: wildcard not allowed as an expression
;   in: _
}

@bold{Meaning}: @racket[_] is a valid @emph{Qi} expression but an invalid @emph{Racket} expression. Somewhere in the course of evaluation of your code, the interpreter received @racket[_] and was asked to evaluate it as a @emph{Racket} expression. It doesn't like this.

@bold{Common example}: Trying to use a template inside a nested application. For instance, @racket[(~> (1) (* 3 (+ _ 2)))] is invalid because, within the @racket[(* ...)] template, the language is @emph{Racket} rather than Qi, and you can't use a Qi template (i.e. @racket[(+ _ 2)]) there. You might try @seclink["Nested_Applications_are_Sequential_Flows"]{sequencing the flow}, something like @racket[(~> (1) (+ _ 2) (* 3))].

@bold{Common example}: Trying to use a Racket macro (rather than a function), or a macro from another DSL, as a flow without first registering it via @racket[define-qi-foreign-syntaxes]. In general, Qi expects flows to be functions unless otherwise explicitly signaled.

@subsubsection{Bad Syntax}

@codeblock{
; lambda: bad syntax
;   in: lambda
}

@bold{Meaning}: The Racket interpreter received syntax, in this case simply "lambda", that it considers to be invalid. Note that if it received something it didn't know anything about, it would say "undefined" rather than "bad syntax." Bad syntax indicates known syntax used in an incorrect way.

@bold{Common example}: A Racket expression has not been properly escaped within a Qi context. For instance, @racket[(flow (lambda (x) x))] is invalid because the wrapped expression is Racket rather than Qi. To fix this, use @racket[esc], as in @racket[(flow (esc (lambda (x) x)))].

@bold{Common example}: Trying to use a Racket macro (rather than a function), or a macro from another DSL, as a flow without first registering it via @racket[define-qi-foreign-syntaxes]. In general, Qi expects flows to be functions unless otherwise explicitly signaled.

@subsubsection{Use Does Not Match Pattern}

@codeblock{
; m: use does not match pattern: (m x y)
;   in: m
}

@bold{Meaning}: A macro was used in a way that doesn't match any declared syntax patterns.

@bold{Common example}: Trying to use a Racket macro (rather than a function), or a macro from another DSL, as a flow without first registering it via @racket[define-qi-foreign-syntaxes]. In general, Qi expects flows to be functions unless otherwise explicitly signaled.

@subsubsection{Expected Identifier Not Starting With Character}

@codeblock{
; syntax-parser: expected identifier not starting with ~ character
;   at: ~optional
}

@bold{Meaning}: A macro attempted to use a @seclink["stxparse-patterns" #:doc '(lib "syntax/scribblings/syntax.scrbl")]{syntax pattern} (which are commonly prefixed with the @racket[~] character) but the parser thinks it's an identifier and doesn't like its name.

@bold{Common example}: Syntax patterns are defined in the @seclink["stxparse" #:doc '(lib "syntax/scribblings/syntax.scrbl")]{syntax/parse} library. If you are using them in Qi macros, you will need to @racket[(require syntax/parse)] at the appropriate phase level.

@subsubsection{Not Defined as Syntax Class}

@codeblock{
; syntax-parser: not defined as syntax class
;   at: expr
}

@bold{Meaning}: A macro attempted to use a @seclink["Syntax_Classes" #:doc '(lib "syntax/scribblings/syntax.scrbl")]{syntax class} that the expander doesn't know about.

@bold{Common example}: Common syntax classes are defined in the @seclink["stxparse" #:doc '(lib "syntax/scribblings/syntax.scrbl")]{syntax/parse} library. If you are using them in Qi macros, you will need to @racket[(require syntax/parse)] at the appropriate phase level (e.g. @racket[(require (for-syntax syntax/parse))].

@subsubsection{Too Many Ellipses in Template}

@codeblock{
; syntax: too many ellipses in template
;   at: ...
}

@bold{Meaning}: A macro template attempted to refer to a syntax pattern matching many @tech/reference{datums} but the parser claims there is no such pattern.

@bold{Common example}: Attempting to use a syntax pattern like @racket[...+] without requiring the @seclink["stxparse" #:doc '(lib "syntax/scribblings/syntax.scrbl")]{syntax/parse} library. When writing Qi macros, you will often need @racket[(require (for-syntax syntax/parse))], the same as when writing Racket macros.

@subsubsection{Syntax: Unbound Identifier}

@codeblock{
; syntax: unbound identifier;
; also, no #%app syntax transformer is bound in the transformer phase
}

@bold{Meaning}: A macro attempted to manipulate a syntax object but the expander doesn't know what that even is.

@bold{Common example}: When writing Qi macros, you will often need @racket[(require (for-syntax racket/base))], the same as when writing Racket macros.

@subsubsection{Undefined}

@codeblock{
; mac: undefined;
;  cannot reference an identifier before its definition
}

@bold{Meaning}: An identifier appears unbound in your code.

@bold{Common example}: Attempting to use a Qi macro in one module without @racketlink[provide]{providing} it from the module where it is defined -- note that Qi macros must be provided as @racket[(provide (for-space qi mac))]. See @secref["Using_Macros" #:doc '(lib "qi/scribblings/qi.scrbl")] for more on this.

@subsubsection{Compose: Contract Violation}

@codeblock{
; compose: contract violation
;   expected: procedure?
;   given: '()
}

@bold{Meaning}: The interpreter attempted to compose functions but encountered a value that was not a function.

@bold{Common example}: Attempting to use @racket[null] as if it were a literal. Use @racket['()] or @racket[(gen null)] instead. See @secref["null_is_Not_a_Literal"] for more.

@subsubsection{List Arity Mismatch}

@codeblock{
; list?: arity mismatch;
;  the expected number of arguments does not match the given number
;   expected: 1
;   given: 2
}

@bold{Meaning}: The predicate @racket[list?] was invoked, and it is complaining that it expects a single input argument but received many.

@bold{Common example}: Attempting to separate multiple input values using @racket[△]. This form separates a single input list into component values, and will produce the above error if it receives more than one input.

@subsubsection{Fancy-app Arity Mismatch}

@codeblock{
; .../fancy-app/main.rkt:28:19: arity mismatch;
;  the expected number of arguments does not match the given number
;   expected: 2
;   given: 1
}

@bold{Meaning}: Qi uses @seclink["top" #:indirect? #t #:doc '(lib "fancy-app/main.scrbl")]{fancy-app} to handle @seclink["Templates_and_Partial_Application"]{partial application templates}. Fancy-app is complaining that it was told to expect a certain number of arguments in the function invocation but received a different number.

@bold{Common example}: You have a template like @racket[(f _ _)] with a certain number of arguments indicated, but it was invoked with more or fewer arguments.

@subsection{Gotchas}

@subsubsection{null is Not a Literal}

In Racket, @racket[null] is another way to indicate the empty list @racket['()], so that @racket[null] and @racket['()] are typically interchangeable. But note that @racket['()] is a @seclink["quote" #:doc '(lib "scribblings/reference/reference.scrbl")]{literal}, while @racket[null] is an @tech/reference{identifier} whose value is @racket['()]. Therefore, as @seclink["Literals"]{Qi interprets literals} as functions generating them, @racket['()] in Qi is treated as a flow that produces the value @racket['()]. On the other hand, as @seclink["Identifiers"]{Qi expects identifiers to be function-valued}, and as @racket[null] isn't a function, using it on its own is an error.

@subsubsection{There's No Escaping @racket[esc]}

If you have a function that returns another function that you'd like to use as a flow (e.g. perhaps parametrized by the first function over some argument), the usual way to do it is something like this:

@racketblock[
    (~> (3) (esc (get-f 1)))
  ]

But in an idle moment, this clever shortcut may tempt you:

@racketblock[
    (~> (3) ((get-f 1)))
  ]

That is, since Qi typically interprets parenthesized expressions as @seclink["Templates_and_Partial_Application"]{partial application templates}, you might expect that this would pass the value @racket[3] to the function resulting from @racket[(get-f 1)]. In fact, that isn't what happens, and an error is raised instead. As there is only one datum within the outer pair of parentheses in @racket[((get-f 1))], the usual interpretation as partial application would not be useful, and could even lead to unexpected behavior (at least, with the current implementation that uses Racket's @racket[curry]). So instead, Qi attempts to interpret the expression as written, that is, as if it were wrapped in @racket[esc]. As a result, it attempts to evaluate @racket[((get-f 1))] and expects to receive a value that can be used as a flow here. If, as in the above expression, the function resulting from @racket[(get-f 1)] expects a single argument, this is now an error as it is being invoked with none.

One way to dodge this is by using an explicit template:

@racketblock[
    (~> (3) ((get-f 1) _))
  ]

This works in most cases, but it has different semantics than the version using @racket[esc], as that version evaluates the escaped expression first to yield the flow that will be applied to inputs, while this one only evaluates the (up to that point, incomplete) expression when it is actually invoked with arguments. In the most common cases there will be no difference to the result, but if the flow is invoked multiple times (for instance, if it were first defined as @racket[(define-flow my-flow (☯ ((get-f 1) _)))]), then the expression too would be evaluated multiple times, producing different functions each time. This may be computationally more expensive than using @racket[esc], and also, if either @racket[get-f] or the function it produces is stateful in any way (for instance, if it is a @hyperlink["https://www.gnu.org/software/guile/manual/html_node/Closure.html"]{closure} or if there is any randomness involved), then this version would also produce different results than the @racket[esc] version.

Another way to do it is to simply promote the expression out of the nest:

@racketblock[
    (~> (3) (get-f 1))
  ]

Now, you might, once again, expect this to be treated as a partial application template, so that this would be equivalent to @racket[(get-f 3 1)] and would raise an error. But in fact, since the expression @racket[(get-f 1)] happens to be fully qualified with all the arguments it needs, the currying employed under the hood to implement partial application in this case @seclink["Using_Racket_to_Define_Flows"]{evaluates to a function result right away}. This then receives the value @racket[3], and consequently, this expression produces the correct result.

So in sum, it's perhaps best to rely on @racket[esc] in such cases to be as explicit as possible about what you mean, rather than rely on quirks of the implementation that are revealed at this boundary between two languages.

@subsubsection{Mutable Values Defy the Laws of Flows}

Qi is designed to model flows of @emph{immutable} values. Using a mutable value in a flow is fine as long as you don't mutate it, or if you mutate it only in a side effect. Otherwise, such values can produce unexpected behavior. For instance, consider the following flow involving a mutable vector:

@racketblock[
    (define vv (vector 1 2 3))
    (~> (vv) (-< _ _) (== (vector-set! 0 5) (vector-set! 2 10)) vector-append)
  ]

You might expect this flow to produce a vector @racket[(vector 5 2 3 1 2 10)], but in fact, it raises an error.

This is because @racket[vector-set!] mutates the vector and produces not the result of the operation but @racket[(void)], since the mutation that is the intent of the function has been performed and there is no need to produce a fresh value. Indeed, mutating interfaces typically produce @racket[(void)], which is not a useful value that could be used in a flow. As a result, the output of the relay is two values, but not the ones we expect, but rather, values that are both @racket[(void)]. These are received by @racket[vector-append], which then complains that it expects vectors but was given @racket[(void)].

Worse still, even though this computation raises an error, we find that the original vector that we started with, @racket[vv], has been mutated to @racket[(vector 5 2 10)], since the same vector is operated on in both channels of the relay prior to the error being encountered.

So in general, use mutable values with caution. Such values can be useful as side effects, for instance to capture some idea of statefulness, perhaps keeping track of the number of times a flow was invoked. But they should generally not be used as inputs to a flow, especially if they are to be mutated.

@section{Effectively Using Feedback Loops}

@racket[feedback] is Qi's most powerful looping form, useful for arbitrary recursion. As it encourages quite a different way of thinking than Racket's usual looping forms do, here are some tips on "grokking" it.

In essence, the feedback loop is very simple –- all it does is pass the same inputs through a flow over and over again until a condition is met, at which point these inputs just flow out of the loop. Nothing complicated at all! The subtlety comes in, though, when we treat some inputs as "control" inputs that determine attributes @emph{of} the flow or as "scratch" inputs that encode computations done @emph{on} the flow, while treating the remaining inputs as the data that are actually acted upon. By doing this, we can do pretty much anything we'd like to, i.e. it can be used for general recursion.

@subsection{Control Values and Data Values}

Prior to entering the feedback loop, augment the data values by starting the "control" or "scratch" flows that the loop will need (although control and scratch inputs are not @emph{quite} the same (see above), we can use the terms interchangeably for our purposes here). In some common cases, this may include a "counter" flow which keeps track of number of iterations, a result flow which accumulates an output, or something of this nature. In addition to these control flows, the loop will, of course, also receive all of the input data in the form of multiple values following the control values. The control inputs must always come first, so that we know where to find them (since we have no idea how many data values there will be at any stage of the loop), so that we can consistently refer to them using e.g. @racket[1>] and @racket[2>].

@subsection{Input Tracing}

For each input, think about just one cycle of the loop: what must happen to it in this cycle before it is fed forward to the next cycle of the loop? Trace each input in this way and ensure that the corresponding output of the present cycle represents the correct input value for the next cycle. For instance, if there is a simple counter in the first @emph{input} position, ensure that the first @emph{output} of the present cycle is the counter incremented by one. We also need to ensure that the same number of @emph{control} values flow to the next cycle as are used in the present cycle. There are no constraints on the number of data values, and often, this will change from one cycle to the next.

@subsection{Keeping It Tidy}

Use the @racket[then] clause to ensure that the feedback loop produces only its computed output and not the "scratch" values used in guiding the flow, i.e., these should be blocked in the @racket[then] clause (using, for instance, @racket[block] or another appropriate form).

@section{Idioms and Transforms}

@subsection{Nested Applications are Sequential Flows}

A nested function application can always be converted to a sequential flow.

@examples[
    #:eval eval-for-docs
    (add1 (* 2 (sqr 5)))
    (~> (5) sqr (* 2) add1)
    (define my-num 5)
    (add1 (* my-num (sqr (+ my-num 3))))
    (~> (my-num) (-< (~> (+ 3) sqr)
                     _) * add1)
  ]

@subsection{Converting a Function to a Closure}

Sometimes you may find you want to go from something like @racket[(~> f1 f2)] to a similar flow except that one of the functions is itself parameterized by an input, i.e. it is a closure. If @racket[f1] is the one that needs to be a closure, you can do it like this: @racket[(~> (==* (clos f1) _) apply f2)], assuming that the closed-over argument to @racket[f1] is passed in as the first input, and the remaining inputs are the data inputs to the flow. Closures are useful in a wide variety of situations, however, and this isn't a one-size-fits-all formula.

@subsection{Converting a Macro to a Flow}

Flows are expected to be @seclink["What_is_a_Flow_"]{function-valued} at runtime, and so you cannot naively use a macro as a flow. You can always convert a macro into a function by employing an @racket[esc] form and wrapping the macro in a lambda.

@examples[
    #:eval eval-for-docs
    (define-syntax-rule (double-me x) (* 2 x))
    (define-syntax-rule (subtract-two x y) (- x y))
    (eval:error (~> (5) (subtract-two _ 4) double-me))
    (~> (5)
        (esc (λ (x) (subtract-two x 4)))
        (esc (λ (x) (double-me x))))
  ]

But this can be cumbersome for anything other than a one-off use of a macro, and it also doesn't take advantage of the syntactic conveniences (such as templates) that Qi already offers. You could write Qi macros to wrap these "foreign" macros and provide all of Qi's usual syntactic behavior, but luckily, you don't need to! Simply use @racket[define-qi-foreign-syntaxes] to "register" any such foreign macros (i.e. macros in any language other than Qi, including Racket) as Qi forms, and then you can use them in the same way as any other function, except that the catch-all @racket[__] template isn't supported.

Using this approach, you would need to register each such foreign macro using @racket[define-qi-foreign-syntaxes] prior to use. Even though you can register as many as you like with a single declaration, this may feel like an impedance, especially for deep integrations with other DSLs where there may be a large number of such forms. See @secref["Qi_Dialect_Interop"] for yet another approach.

@subsection{Bindings are an Alternative to Nonlinearity}

In some cases, we'd prefer to think of a nonlinear flow as a linear sequence on a subset of arguments that happens to need the remainder of the arguments somewhere down the line. In such cases, it is advisable to employ bindings so that the flow can be defined on this subset of them and employ the remainder by name.

For example, these are equivalent:

@codeblock{
  (define-flow make-document
    (~> (== _
            (~>> file-contents
                 (parse-result document/p)
                 △))
        document))
}

@codeblock{
  (define (make-document name file)
    (~>> (file)
         file-contents
         (parse-result document/p)
         △
         (document name)))
}

Adding bindings can eliminate nonlinearities, and by the same token, introducing nonlinearity can eliminate bindings.

@close-eval[eval-for-docs]
@(set! eval-for-docs #f)
