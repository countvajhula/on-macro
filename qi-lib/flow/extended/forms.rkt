#lang racket/base

(provide (for-space qi
                    (all-defined-out)
                    ;; defining and using a `define-qi-alias` form
                    ;; would be a more direct way to do this
                    (rename-out [thread-right ~>>]
                                [crossover X]
                                [relay* ==*]
                                [effect ε])))

(require (for-syntax racket/base
                     "syntax.rkt"
                     "../aux-syntax.rkt")
         syntax/parse/define
         "expander.rkt"
         "../../macro.rkt"
         (only-in "../space.rkt"
                  define-for-qi)
         "impl.rkt")

;;; Predicates

(define-for-qi all? ~all?)

(define-for-qi AND ~all?)

(define-for-qi OR ~any?)

(define-for-qi any? ~any?)

(define-for-qi none? ~none?)

(define-core-qi-syntax-rule (one-of? v:expr ...)
  (~> (member (list v ...)) ->boolean))

(define-core-qi-syntax-rule (none onex:clause)
  (not (any onex)))

(define-core-qi-syntax-parser NOR
  [_:id #'(~> OR NOT)])

(define-core-qi-syntax-parser NAND
  [_:id #'(~> AND NOT)])

(define-core-qi-syntax-parser XNOR
  [_:id #'(~> XOR NOT)])

(define-core-qi-syntax-rule (and% onex:conjux-clause ...)
  (~> (== onex.parsed ...)
      all?))

(define-core-qi-syntax-rule (or% onex:disjux-clause ...)
  (~> (== onex.parsed ...)
      any?))

;;; Routing

;; Right-threading is just normal threading but with a syntax
;; property attached to the components indicating the chirality
(define-core-qi-syntax-rule (thread-right onex:right-threading-clause ...)
  (~> onex.chiral ...))

(define-core-qi-syntax-parser crossover
  [_:id #'(~> ▽ reverse △)])

(define-core-qi-syntax-parser relay*
  [(_ onex:clause ... rest-onex:clause)
   #:with len #`#,(length (syntax->list #'(onex ...)))
   #'(group len (== onex ...) rest-onex)])

(define-core-qi-syntax-rule (bundle (n:number ...)
                                    selection-onex:clause
                                    remainder-onex:clause)
  (-< (~> (select n ...) selection-onex)
      (~> (block n ...) remainder-onex)))

;;; Conditionals

(define-core-qi-syntax-rule (when condition:clause
                              consequent:clause)
  (if condition consequent ⏚))

(define-core-qi-syntax-rule (unless condition:clause
                              alternative:clause)
  (if condition ⏚ alternative))

(define-core-qi-syntax-parser switch
  [(_) #'_]
  [(_ ((~or* (~datum divert) (~datum %))
       condition-gate:clause
       consequent-gate:clause))
   #'consequent-gate]
  [(_ [(~datum else) alternative:clause])
   #'alternative]
  [(_ ((~or* (~datum divert) (~datum %))
       condition-gate:clause
       consequent-gate:clause)
      [(~datum else) alternative:clause])
   #'(~> consequent-gate alternative)]
  [(_ [condition0:clause ((~datum =>) consequent0:clause ...)]
      [condition:clause consequent:clause]
      ...)
   ;; we split the flow ahead of time to avoid evaluating
   ;; the condition more than once
   #'(~> (-< condition0 _)
         (if 1>
             (~> consequent0 ...)
             (group 1 ⏚
                    (switch [condition consequent]
                      ...))))]
  [(_ ((~or* (~datum divert) (~datum %))
       condition-gate:clause
       consequent-gate:clause)
      [condition0:clause ((~datum =>) consequent0:clause ...)]
      [condition:clause consequent:clause]
      ...)
   ;; both divert as well as => clauses. Here, the divert clause
   ;; operates on the original inputs, not including the result
   ;; of the condition flow.
   ;; as before, we split the flow ahead of time to avoid evaluating
   ;; the condition more than once
   #'(~> (-< (~> condition-gate condition0) _)
         (if 1>
             (~> (group 1 _ consequent-gate)
                 consequent0 ...)
             (group 1 ⏚
                    (switch (divert condition-gate consequent-gate)
                      [condition consequent]
                      ...))))]
  [(_ [condition0:clause consequent0:clause]
      [condition:clause consequent:clause]
      ...)
   #'(if condition0
         consequent0
         (switch [condition consequent]
           ...))]
  [(_ ((~or* (~datum divert) (~datum %))
       condition-gate:clause
       consequent-gate:clause)
      [condition0:clause consequent0:clause]
      [condition:clause consequent:clause]
      ...)
   #'(if (~> condition-gate condition0)
         (~> consequent-gate consequent0)
         (switch (divert condition-gate consequent-gate)
           [condition consequent]
           ...))])

(define-core-qi-syntax-rule (gate onex:clause)
  (if onex _ ⏚))

;;; Common utilities

(define-for-qi count ~count)

(define-for-qi live? ~live?)

(define-core-qi-syntax-rule (rectify v:expr ...)
  (if live? _ (gen v ...)))

;;; High level circuit elements

;; aliases for inputs
(define-core-qi-syntax-parser 1>
  [_:id #'(select 1)])
(define-core-qi-syntax-parser 2>
  [_:id #'(select 2)])
(define-core-qi-syntax-parser 3>
  [_:id #'(select 3)])
(define-core-qi-syntax-parser 4>
  [_:id #'(select 4)])
(define-core-qi-syntax-parser 5>
  [_:id #'(select 5)])
(define-core-qi-syntax-parser 6>
  [_:id #'(select 6)])
(define-core-qi-syntax-parser 7>
  [_:id #'(select 7)])
(define-core-qi-syntax-parser 8>
  [_:id #'(select 8)])
(define-core-qi-syntax-parser 9>
  [_:id #'(select 9)])

(define-core-qi-syntax-parser inverter
  [_:id #'(>< NOT)])

(define-core-qi-syntax-parser effect
  [(_ sidex:clause onex:clause)
   #'(-< (~> sidex ⏚)
         onex)]
  [(_ sidex:clause)
   #'(-< (~> sidex ⏚)
         _)])
