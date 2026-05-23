;;; jinja2-mode-test.el --- Buttercup tests for jinja2-mode -*- lexical-binding: t -*-

;; Copyright (C) 2026 A Lloyd Flanagan

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; Commentary:

;; Buttercup test suite for jinja2-mode.  Run with:
;;
;;     cask exec buttercup -L .
;;
;; The suite covers the keyword-list functions, font-lock highlighting,
;; indentation, tag closing/insertion, and mode setup.

;;; Code:

(require 'buttercup)
(require 'jinja2-mode)

;;; Helpers

(defmacro jinja2-test--in-buffer (text &rest body)
  "Evaluate BODY in a temporary `jinja2-mode' buffer holding TEXT.
Point starts at the beginning of the buffer."
  (declare (indent 1) (debug (form body)))
  `(with-temp-buffer
     (insert ,text)
     (jinja2-mode)
     (goto-char (point-min))
     ,@body))

(defun jinja2-test--reindent (text)
  "Return TEXT after running `jinja2-indent-buffer' over it."
  (with-temp-buffer
    (insert text)
    (jinja2-mode)
    (jinja2-indent-buffer)
    (buffer-string)))

(defun jinja2-test--face-of (text needle)
  "Fontify TEXT in `jinja2-mode' and return the face at the start of NEEDLE.
Font-lock is forced to its highest decoration level so the Jinja2
keyword set is active."
  (with-temp-buffer
    (let ((font-lock-maximum-decoration t))
      (insert text)
      (jinja2-mode)
      (font-lock-ensure)
      (goto-char (point-min))
      (search-forward needle)
      (get-text-property (match-beginning 0) 'face))))

(defun jinja2-test--has-face (face value)
  "Return non-nil when FACE is, or is a member of, the face property VALUE."
  (cond ((null value) nil)
        ((listp value) (memq face value))
        (t (eq face value))))

;;; Keyword lists

(describe "keyword list functions"

  (it "returns the built-in closing keywords"
    (let ((jinja2-user-keywords nil))
      (expect (jinja2-closing-keywords)
              :to-equal '("autoescape" "block" "call" "filter" "for"
                          "if" "macro" "raw" "set" "trans" "with"))))

  (it "does not list else/elif as closing keywords"
    (let ((jinja2-user-keywords nil))
      (expect (member "else" (jinja2-closing-keywords)) :to-be nil)
      (expect (member "elif" (jinja2-closing-keywords)) :to-be nil)))

  (it "prepends jinja2-user-keywords to the closing keywords"
    (let ((jinja2-user-keywords '("mytag")))
      (expect (car (jinja2-closing-keywords)) :to-equal "mytag")
      (expect (member "if" (jinja2-closing-keywords)) :to-be-truthy)))

  (it "adds else and elif to the indenting keywords"
    (let ((jinja2-user-keywords nil))
      (expect (member "else" (jinja2-indenting-keywords)) :to-be-truthy)
      (expect (member "elif" (jinja2-indenting-keywords)) :to-be-truthy)
      (expect (member "for" (jinja2-indenting-keywords)) :to-be-truthy)))

  (it "lists builtin keywords such as extends and include"
    (expect (member "extends" (jinja2-builtin-keywords)) :to-be-truthy)
    (expect (member "include" (jinja2-builtin-keywords)) :to-be-truthy))

  (it "lists builtin filter functions such as upper and join"
    (let ((jinja2-user-functions nil))
      (expect (member "upper" (jinja2-functions-keywords)) :to-be-truthy)
      (expect (member "join" (jinja2-functions-keywords)) :to-be-truthy)))

  (it "prepends jinja2-user-functions to the filter functions"
    (let ((jinja2-user-functions '("myfilter")))
      (expect (car (jinja2-functions-keywords)) :to-equal "myfilter")
      (expect (member "upper" (jinja2-functions-keywords)) :to-be-truthy))))

;;; Tag finding and closing

(describe "jinja2-find-open-tag"

  (it "finds the nearest unclosed block tag"
    (jinja2-test--in-buffer "{% for a in b %}\n{% if c %}\n"
      (goto-char (point-max))
      (expect (jinja2-find-open-tag) :to-equal '("if" " c"))))

  (it "returns nil when there is no open tag"
    (jinja2-test--in-buffer "plain text\n"
      (goto-char (point-max))
      (expect (jinja2-find-open-tag) :to-be nil))))

(describe "jinja2-close-tag"

  (it "inserts a matching end tag for a simple block"
    (jinja2-test--in-buffer "{% if x %}\n"
      (goto-char (point-max))
      (jinja2-close-tag)
      (expect (buffer-string) :to-equal "{% if x %}\n{% endif %}")))

  (it "echoes the block name when closing a block tag"
    (jinja2-test--in-buffer "{% block content %}\n"
      (goto-char (point-max))
      (jinja2-close-tag)
      (expect (buffer-string)
              :to-equal "{% block content %}\n{% endblock content %}")))

  (it "closes a for loop"
    (jinja2-test--in-buffer "{% for x in y %}\n"
      (goto-char (point-max))
      (jinja2-close-tag)
      (expect (buffer-string) :to-equal "{% for x in y %}\n{% endfor %}")))

  (it "signals an error when there is nothing to close"
    (jinja2-test--in-buffer "just text\n"
      (goto-char (point-max))
      (expect (jinja2-close-tag) :to-throw 'error))))

;;; Tag insertion

(describe "tag insertion commands"

  (it "inserts an empty statement tag with point inside"
    (jinja2-test--in-buffer ""
      (jinja2-insert-tag)
      (expect (buffer-string) :to-equal "{%  %}")
      (expect (point) :to-equal 4)))

  (it "inserts an empty variable tag with point inside"
    (jinja2-test--in-buffer ""
      (jinja2-insert-var)
      (expect (buffer-string) :to-equal "{{  }}")
      (expect (point) :to-equal 4)))

  (it "inserts an empty comment tag with point inside"
    (jinja2-test--in-buffer ""
      (jinja2-insert-comment)
      (expect (buffer-string) :to-equal "{#  #}")
      (expect (point) :to-equal 4))))

;;; Indentation

(describe "indentation"

  (it "indents the body of a for block"
    (expect (jinja2-test--reindent
             "{% for x in y %}\nhello\n{% endfor %}\n")
            :to-equal
            "{% for x in y %}\n  hello\n{% endfor %}\n"))

  (it "dedents else and re-indents both branches"
    (expect (jinja2-test--reindent
             "{% if a %}\nx\n{% else %}\ny\n{% endif %}\n")
            :to-equal
            "{% if a %}\n  x\n{% else %}\n  y\n{% endif %}\n"))

  (it "indents nested blocks cumulatively"
    (expect (jinja2-test--reindent
             "{% for a in b %}\n{% if c %}\nx\n{% endif %}\n{% endfor %}\n")
            :to-equal
            (concat "{% for a in b %}\n"
                    "  {% if c %}\n"
                    "    x\n"
                    "  {% endif %}\n"
                    "{% endfor %}\n")))

  (it "leaves an already-correct buffer unchanged"
    (let ((text "{% for x in y %}\n  hello\n{% endfor %}\n"))
      (expect (jinja2-test--reindent text) :to-equal text))))

;;; Font-lock

(describe "font-lock highlighting"

  (it "highlights variable names inside {{ }}"
    (expect (jinja2-test--has-face
             'font-lock-variable-name-face
             (jinja2-test--face-of "{{ name }}" "name"))
            :to-be-truthy))

  (it "highlights block keywords inside {% %}"
    (expect (jinja2-test--has-face
             'font-lock-keyword-face
             (jinja2-test--face-of "{% if x %}" "if"))
            :to-be-truthy))

  (it "highlights comment bodies inside {# #}"
    (expect (jinja2-test--has-face
             'font-lock-comment-face
             (jinja2-test--face-of "{# a note #}" "a note"))
            :to-be-truthy))

  (it "highlights builtin keywords"
    (expect (jinja2-test--has-face
             'font-lock-builtin-face
             (jinja2-test--face-of "{% extends x %}" "extends"))
            :to-be-truthy))

  (it "highlights builtin filter functions"
    (expect (jinja2-test--has-face
             'font-lock-function-name-face
             (jinja2-test--face-of "{{ x|upper }}" "upper"))
            :to-be-truthy)))

;;; Mode setup

(describe "jinja2-mode setup"

  (it "derives from html-mode"
    (jinja2-test--in-buffer ""
      (expect (derived-mode-p 'html-mode) :to-be-truthy)))

  (it "uses Jinja2 comment delimiters"
    (jinja2-test--in-buffer ""
      (expect comment-start :to-equal "{#")
      (expect comment-end :to-equal "#}")))

  (it "installs jinja2-indent-line as the indent function"
    (jinja2-test--in-buffer ""
      (expect indent-line-function :to-be 'jinja2-indent-line)))

  (it "binds the tag editing commands in the mode map"
    (expect (lookup-key jinja2-mode-map (kbd "C-c c"))
            :to-be 'jinja2-close-tag)
    (expect (lookup-key jinja2-mode-map (kbd "C-c t"))
            :to-be 'jinja2-insert-tag)
    (expect (lookup-key jinja2-mode-map (kbd "C-c v"))
            :to-be 'jinja2-insert-var)
    (expect (lookup-key jinja2-mode-map (kbd "C-c #"))
            :to-be 'jinja2-insert-comment))

  (it "registers the .j2 and .jinja2 file extensions"
    (expect (cdr (assoc "\\.j2\\'" auto-mode-alist)) :to-be 'jinja2-mode)
    (expect (cdr (assoc "\\.jinja2\\'" auto-mode-alist))
            :to-be 'jinja2-mode)))

;;; jinja2-mode-test.el ends here
