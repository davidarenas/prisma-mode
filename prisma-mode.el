(defgroup prisma-mode nil "Major mode of Prisma Schema Language."
  :group 'languages)

(defcustom prisma-format-on-save nil "Format prisma buffers before saving using prisma-fmt."
  :type 'boolean
  :safe #'booleanp
  :group 'prisma-mode)


(defun prisma-fmt-buffer ()
  (interactive)
  (let ((this-buffer (current-buffer))
        (prisma-fmt-cmd "prisma-fmt")
        (prisma-fmt-args (list "format"))
        (temp-out-buffer (generate-new-buffer " *prisma-fmt*"))
        (temp-err-file (make-temp-file "prisma-fmt" nil ".el"))
        (default-process-coding-system '(utf-8-unix . utf-8-unix)))
    (condition-case err
        (unwind-protect
            (let ((status (progn
                            (apply #'call-process-region
                                   nil
                                   nil
                                   prisma-fmt-cmd
                                   nil
                                   `(,temp-out-buffer ,temp-err-file)
                                   nil
                                   prisma-fmt-args)))
                  (stderr (with-temp-buffer
                            (unless (zerop (cadr (insert-file-contents temp-err-file)))
                              (insert ": "))
                            (buffer-substring-no-properties (point-min)
                                                            (point-max)))))
              (cond
               ((stringp status)
                (error "(prisma-fmt killed by signal %s%s)"
                       status stderr))
               ((not (zerop status))
                (error "(prisma-fmt failed with code %d%s)"
                       status stderr))
               (t (with-current-buffer this-buffer
                    (replace-buffer-contents temp-out-buffer))
                  (message "(prisma-fmt applied)")))))
      (error (message "%s"
                      (error-message-string err))))
    (delete-file temp-err-file)
    (when (buffer-name temp-out-buffer)
      (kill-buffer temp-out-buffer))))


(defun prisma-fmt-save-hook ()
  (add-hook 'before-save-hook
            (lambda ()
              (progn
                (when prisma-format-on-save
                  (prisma-fmt-buffer))
                nil))
            nil
            t))

(defconst prisma--block-regexp "^\\s-*\\(datasource\\|generator\\|model\\|enum\\|type\\)\\s-*\\([[:word:]]+\\)\\s-*{")

(defconst prisma--attribute-regexp "\\s-*\\(\\@\\|@@\\)\\([[:word:]]+\\)\\((?\\)")

(defconst prisma--function-regexp "\\s-*\\([[:word:]]+\\)\\((\\)")

(defconst prisma--string-interpolation-regexp "\\${[^}\n\\\\]*\\(?:\\\\.[^}\n\\\\]*\\)*}")

(defconst prisma--assignment-regexp "\\s-*\\([[:word:]]+\\)\\s-*=\\(?:[^>=]\\)")

(defconst prisma--map-regexp "\\s-*\\([[:word:]]+\\)\\s-*{")

(defconst prisma--field-regexp "^\\s-*\\([[:word:]]+\\)\\s-+\\([[:word:]]+\\)\\(\\[]\\)?\\(\\?\\)?\\(\\!\\)?")

(defconst prisma--map-key-regex "\\([[:word:]]+\\)\\s-*\\(:\\)\\s-*")


(defconst prisma--boolean-regexp (concat "\\(?:^\\|[^.]\\)"
                                         (regexp-opt '("true" "false")
                                                     'words)))

(defvar prisma-font-lock-keywords `((,prisma--block-regexp
                                     (1 font-lock-keyword-face)
                                     (2 font-lock-type-face))
                                    (,prisma--assignment-regexp
                                     (1 font-lock-variable-name-face))
                                    (,prisma--field-regexp
                                     (1 font-lock-variable-name-face)
                                     (2 font-lock-type-face))
                                    (,prisma--map-key-regex 1 font-lock-variable-name-face)
                                    (,prisma--attribute-regexp . font-lock-function-name-face)
                                    (,prisma--boolean-regexp 1 font-lock-constant-face)
                                    (,prisma--function-regexp . font-lock-function-name-face)
                                    (,prisma--string-interpolation-regexp 0 font-lock-variable-name-face
                                                                          t)))


(define-derived-mode prisma-mode
  prog-mode
  "Prisma"
  "Major mode for editing Prisma Schema Language files"
  (setq font-lock-defaults '((prisma-font-lock-keywords)))
  (prisma-fmt-save-hook))

(progn
  (add-to-list 'auto-mode-alist
               '("\\.prisma\\'" . prisma-mode)))

(provide 'prisma-mode)
