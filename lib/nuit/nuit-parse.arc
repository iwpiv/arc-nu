(import re)

(= nuit-whitespace   (string "\u9\uB\uC\u85\uA0\u1680\u180E\u2000-\u200A"
                             "\u2028\u2029\u202F\u205F\u3000")
   nuit-nonprinting  (string "\u0-\u8\uE-\u1F\u7F-\u84\u86-\u9F\uFDD0-\uFDEF"
                             "\uFEFF\uFFFE\uFFFF\U1FFFE\U1FFFF\U10FFFE\U10FFFF")
   nuit-end-of-line  "(?:\uD\uA|[\uD\uA]|$)"
   nuit-invalid      (string nuit-whitespace nuit-nonprinting))

(def f-err (message line lines column)
  (let column (if (< column 1)
                  1
                  column)
    (err:string message "\n  " line
      "  (line " lines ", column " column ")\n"
      " " (newstring column #\space) "^")))

(def nuit-normalize (s)
  ;; Byte Order Mark may only appear at the start of the stream and is ignored
  (re-match "^\uFEFF" s)
  (alet lines 1
    (when peekc.s
                 ;; Different line endings are converted to U+000A
      (withs (x  (cadr:re-match (string "^([^\r\n]*)" nuit-end-of-line) s)
                 ;; U+0020 at the end of the line is ignored
              x  (re-replace " +$" x ""))
                     ;; Invalid characters are not allowed anywhere
        (iflet (pos) (re-posmatch1 (string "[" nuit-invalid "]") x)
          (f-err (string "invalid character " x.pos) x lines (+ pos 1))
          (cons x (self (+ lines 1))))))))

;; Calls `f`, passing it the `self` iterator and the line state
;;
;; When `f` terminates, it will optionally call `after` with the lines,
;; line number, and the result of `f`
;;
;; `after` behaves somewhat like a continuation, letting you throw control
;; back to a different area of the program while maintaining the correct
;; line state
(def nuit-while1 (s lines f (o after))
  (let x (awith (s2      s
                 lines2  lines)
           (= s s2 lines lines2)
           (when s
             (let (i str) (cdr:re-match "^( *)(.*)" car.s2)
               (f self s2 lines2 len.i str))))
    (if after
        (after s lines x)
        x)))

;; Helper function that's used a lot
;;
;; Exactly like `nuit-while1` except empty lines are always ignored
(def nuit-while (s lines f (o after))
  (nuit-while1 s lines (fn (self s lines i str)
                         (if (is str "")
                             (self cdr.s (+ lines 1))
                             (f self s lines i str)))
                       after))

;; Finds the indent of the first line that has an indent greater than `index`
;;
;; If it finds a non-empty line that has an indent less than or equal to
;; `index` it will return `nil`
(def nuit-find-indent (index s)
  (nuit-while s 0
    (fn (self s lines i str)
      (when (and index (>= i index)) i))))

;; Returns a function that is suitable for passing to `nuit-while`
;;
;; It will return a list of parsed values that have an indent that is
;; matched by `op` and `index`
;;
;; If `op` doesn't match the indent it will optionally call `f` to return an
;; alternate result
(def nuit-parse-index (op index (o f))
  (fn (self s lines i str)
    (if (op i index)
          (aif (nuit-parsers str.0)
               (it self s lines (+ i 1) (cut str 1))
               (cons str (self cdr.s (+ lines 1))))
        f
          (f self s lines i str))))

;; Parses an inline expression. It's only used for the second item in @
(def nuit-parse-inline (s lines i str f)
  (aif (nuit-parsers str.0)
       (let x (it (fn (s2 lines2)
                    (= s s2 lines lines2)
                    nil)
                  s lines (+ i 1) (cut str 1))
         (f s lines x))
       (f cdr.s (+ lines 1) (list str))))

(def nuit-parse-string (sep (o f))
  (fn (next s lines index str)
    (withs (index     (+ index 1)
            (s? str)  (if (is str "")
                            (list nil str)
                          (is str.0 #\space)
                            (let str (cut str 1)
                              (if f (f sep s lines index str)
                                    (list sep str)))
                          (f-err (string "expected space or newline but got " str.0)
                                 car.s lines index)))
      (nuit-while1 cdr.s (+ lines 1)
        (fn (self s lines i str)
          (if (is str "")
                (do (= s? #\newline)
                    (cons #\newline (self cdr.s (+ lines 1))))
              (>= i index)
                (let (n? str) (if f (f sep s lines i str)
                                    (list sep str))
                  (list* (do1 s? (= s? n?))
                         (newstring (- i index) #\space)
                         str
                         (self cdr.s (+ lines 1))))))
        (fn (s lines x)
          (cons (string str x)
                (next s lines)))))))

(def nuit-hex->char (x)
  (coerce (coerce x 'int 16) 'char))

(def nuit-parse-unicode (next s lines i str)
  (if (re-match "^\\(" str)
      (alet i i
        (let (h end) (cdr:re-match "([0-9a-fA-F]*)(.?)" str)
          (let i (+ i len.h 1)
            (if (and (is end " ")
                     (isnt h ""))
                  (cons nuit-hex->char.h self.i)
                (and (is end ")")
                     (isnt h ""))
                  (cons nuit-hex->char.h next.i)
                (is end "")
                  (f-err "expected space or ) but got newline" car.s lines (+ i 1))
                (f-err (string "expected hexadecimal but got "
                               (if (is end " ") "space" end))
                       car.s lines (+ i 1))))))
      (f-err (string "expected ( but got " (or peekc.str "newline"))
             car.s lines (+ i 1))))

(def nuit-parse-escape (sep s lines i str)
  (withs (str  (instring str)
          x    (alet i i
                 (let (start end) (cdr:re-match "^(.*?)\\\\(.?)" str)
                   (let i (+ i len.start 2)
                         ;; The character \ wasn't found in the string
                     (if (no start)
                           (list allchars.str)
                         ;; The character \ is the last character in the string
                         (is end "")
                           (do (= sep #\newline)
                               start)
                         (is end "\\")
                           (list* start end self.i)
                         (is end "s")
                           (list* start #\space self.i)
                         (is end "n")
                           (list* start #\newline self.i)
                         (is end "u")
                           (cons start (nuit-parse-unicode self s lines i str))
                         (f-err (string "expected any of [newline \\ s n u] but got " end)
                                car.s lines i))))))
    (list sep string.x)))

(= nuit-parsers
   (obj #\@ (fn (next s lines i str)
              (let (first space rest) (cdr:re-match "^([^ ]*)( *)(.*)" str)
                (let body (fn (s lines rest)
                            (let index (nuit-find-indent i s)
                              (nuit-while s lines
                                (nuit-parse-index is index)
                                (fn (s lines x)
                                  (let x rest.x
                                    (cons (if (is first "")
                                              x
                                              (cons first x))
                                          (next s lines)))))))
                  (if (is rest "")
                      (body cdr.s (+ lines 1) idfn)
                      (let i (+ i (len:string first space))
                        (nuit-parse-inline s lines i rest
                          (fn (s lines x)
                            (if x
                                (body s lines (fn (y) (cons car.x y)))
                                (body s lines idfn)))))))))
        #\# (fn (next s lines index str)
              (nuit-while cdr.s (+ lines 1)
                ;; Consumes all the lines that have an indent greater
                ;; than or equal to `index`
                (fn (self s lines i str)
                  (when (>= i index)
                    (self cdr.s (+ lines 1))))
                ;; Calls `next` so that the value of # is ignored
                (fn (s lines x)
                  (next s lines))))
        #\` (nuit-parse-string #\newline)
        #\" (nuit-parse-string #\space nuit-parse-escape)))

(def nuit-parse (s)
  (let s (nuit-normalize (if (isa s 'string)
                             (instring s)
                             s))
    (let index (nuit-find-indent 0 s)
      (nuit-while s 1
        (nuit-parse-index is index
          (fn (self s lines i str)
            (f-err (string "expected an indent of " index " but got " i)
                   car.s lines i)))))))
