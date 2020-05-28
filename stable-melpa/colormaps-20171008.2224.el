;;; colormaps.el --- Hex colormaps

;; Copyright (c) 2017 Abhinav Tushar

;; Author: Abhinav Tushar <lepisma@fastmail.com>
;; Version: 0.1.2
;; Package-Version: 20171008.2224
;; Package-Commit: 19fbb64a6288d505b9cf45c9b5a3eed0bfb135e2
;; Package-Requires: ((emacs "25"))
;; Keywords: tools
;; URL: https://github.com/lepisma/colormaps.el

;;; Commentary:

;; colormaps.el lets you use color schemes from popular plotting libraries
;; This file is not a part of GNU Emacs.

;;; License:

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <http://www.gnu.org/licenses/>.

;;; Code:

(require 'cl-lib)
(require 'color)
(require 'pcase)

(defconst colormaps-cmaps
  '((viridis . ((0.00 . (68  1   84 ))
                (0.13 . (71  44  122))
                (0.25 . (59  81  139))
                (0.38 . (44  113 142))
                (0.50 . (33  144 141))
                (0.63 . (39  173 129))
                (0.75 . (92  200 99 ))
                (0.88 . (170 220 50 ))
                (1.00 . (253 231 37 ))))
    (inferno . ((0.00 . (0   0   4  ))
                (0.13 . (31  12  72 ))
                (0.25 . (85  15  109))
                (0.38 . (136 34  106))
                (0.50 . (186 54  85 ))
                (0.63 . (227 89  51 ))
                (0.75 . (249 140 10 ))
                (0.88 . (249 201 50 ))
                (1.00 . (252 255 164))))
    (magma . ((0.00 . (0   0   4  ))
              (0.13 . (28  16  68 ))
              (0.25 . (79  18  123))
              (0.38 . (129 37  129))
              (0.50 . (181 54  122))
              (0.63 . (229 80  100))
              (0.75 . (251 135 97 ))
              (0.88 . (254 194 135))
              (1.00 . (252 253 191))))
    (plasma . ((0.00 . (13  8   135))
               (0.13 . (75  3   161))
               (0.25 . (125 3   168))
               (0.38 . (168 34  150))
               (0.50 . (203 70  121))
               (0.63 . (229 107 93 ))
               (0.75 . (248 148 65 ))
               (0.88 . (253 195 40 ))
               (1.00 . (240 249 33 ))))
    (jet . ((0.000 . (0   0   131))
            (0.125 . (0   60  170))
            (0.375 . (5   255 255))
            (0.625 . (255 255 0  ))
            (0.875 . (250 0   0  ))
            (1.000 . (128 0   0  ))))
    (hsv . ((0.000 . (255 0   0  ))
            (0.169 . (253 255 2  ))
            (0.173 . (247 255 2  ))
            (0.337 . (0   252 4  ))
            (0.341 . (0   252 10 ))
            (0.506 . (1   249 255))
            (0.671 . (2   0   253))
            (0.675 . (8   0   253))
            (0.839 . (255 0   251))
            (0.843 . (255 0   245))
            (1.000 . (255 0   6  ))))
    (hot . ((0.0 . (0   0   0  ))
            (0.3 . (230 0   0  ))
            (0.6 . (255 210 0  ))
            (1.0 . (255 255 255))))
    (cool . ((0.00 . (125 0   179))
             (0.13 . (116 0   218))
             (0.25 . (98  74  237))
             (0.38 . (68  146 231))
             (0.50 . (0   204 197))
             (0.63 . (0   247 146))
             (0.75 . (0   255 88 ))
             (0.88 . (40  255 8  ))
             (1.00 . (147 255 0  ))))
    (spring . ((0.0 . (255 0   255))
               (1.0 . (255 255 0  ))))
    (summer . ((0.0 . (0   128 102))
               (1.0 . (255 255 102))))
    (autumn . ((0.0 . (255 0   0  ))
               (1.0 . (255 255 0  ))))
    (winter . ((0.0 . (0   0   255))
               (1.0 . (0   255 128))))
    (bone . ((0.000 . (0   0   0  ))
             (0.376 . (84  84  116))
             (0.753 . (169 200 200))
             (1.000 . (255 255 255))))
    (copper . ((0.000 . (0   0   0  ))
               (0.804 . (255 160 102))
               (1.000 . (255 199 127))))
    (greys . ((0.0 . (0   0   0  ))
              (1.0 . (255 255 255))))
    (yignbu . ((0.000 . (8   29  88 ))
               (0.125 . (37  52  148))
               (0.250 . (34  94  168))
               (0.375 . (29  145 192))
               (0.500 . (65  182 196))
               (0.625 . (127 205 187))
               (0.750 . (199 233 180))
               (0.875 . (237 248 217))
               (1.000 . (255 255 217))))
    (greens . ((0.000 . (0   68  27 ))
               (0.125 . (0   109 44 ))
               (0.250 . (35  139 69 ))
               (0.375 . (65  171 93 ))
               (0.500 . (116 196 118))
               (0.625 . (161 217 155))
               (0.750 . (199 233 192))
               (0.875 . (229 245 224))
               (1.000 . (247 252 245))))
    (yiorrd . ((0.000 . (128 0   38 ))
               (0.125 . (189 0   38 ))
               (0.250 . (227 26  28 ))
               (0.375 . (252 78  42 ))
               (0.500 . (253 141 60 ))
               (0.625 . (254 178 76 ))
               (0.750 . (254 217 118))
               (0.875 . (255 237 160))
               (1.000 . (255 255 204))))
    (bluered . ((0.0 . (0   0   255))
                (1.0 . (255 0   0  ))))
    (rdbu . ((0.00 . (5   10  172))
             (0.35 . (106 137 247))
             (0.50 . (190 190 190))
             (0.60 . (220 170 132))
             (0.70 . (230 145 90 ))
             (1.00 . (178 10  28 ))))
    (picnic . ((0.0 . (0   0   255))
               (0.1 . (51  153 255))
               (0.2 . (102 204 255))
               (0.3 . (153 204 255))
               (0.4 . (204 204 255))
               (0.5 . (255 255 255))
               (0.6 . (255 204 255))
               (0.7 . (255 153 255))
               (0.8 . (255 102 204))
               (0.9 . (255 102 102))
               (1.0 . (255 0   0  ))))
    (rainbow . ((0.000 . (150 0  90))
                (0.125 . (0   0  200))
                (0.250 . (0   25 255))
                (0.375 . (0   152 255))
                (0.500 . (44  255 150))
                (0.625 . (151 255 0  ))
                (0.750 . (255 234 0  ))
                (0.875 . (255 111 0  ))
                (1.000 . (255 0   0  ))))
    (portland . ((0.00 . (12  51  131))
                 (0.25 . (10  136 186))
                 (0.50 . (242 211 56 ))
                 (0.75 . (242 143 56 ))
                 (1.00 . (217 30  30 ))))
    (blackbody . ((0.0 . (0   0   0  ))
                  (0.2 . (230 0   0  ))
                  (0.4 . (230 210 0  ))
                  (0.7 . (255 255 255))
                  (1.0 . (160 200 255))))
    (earth . ((0.0 . (0   0   130))
              (0.1 . (0   180 180))
              (0.2 . (40  210 40 ))
              (0.4 . (230 230 50 ))
              (0.6 . (120 70  20 ))
              (1.0 . (255 255 255))))
    (electric . ((0.00 . (0   0   0  ))
                 (0.15 . (30  0   100))
                 (0.40 . (120 0   100))
                 (0.60 . (160 90  0  ))
                 (0.80 . (230 200 0  ))
                 (1.00 . (255 250 220))))
    (warm . ((0.00 . (125 0   179))
             (0.13 . (172 0   187))
             (0.25 . (219 0   170))
             (0.38 . (255 0   130))
             (0.50 . (255 63  74 ))
             (0.63 . (255 123 0  ))
             (0.75 . (234 176 0  ))
             (0.88 . (190 228 0  ))
             (1.00 . (147 255 0  ))))
    (rainbow-soft . ((0.0 . (125 0   179))
                     (0.1 . (199 0   180))
                     (0.2 . (255 0   121))
                     (0.3 . (255 108 0  ))
                     (0.4 . (222 194 0  ))
                     (0.5 . (150 255 0  ))
                     (0.6 . (0   255 55 ))
                     (0.7 . (0   246 150))
                     (0.8 . (50  167 222))
                     (0.9 . (103 51  235))
                     (1.0 . (124 0   186))))
    (bathymetry . ((0.00 . (40  26  44 ))
                   (0.13 . (59  49  90 ))
                   (0.25 . (64  76  139))
                   (0.38 . (63  110 151))
                   (0.50 . (72  142 158))
                   (0.63 . (85  174 163))
                   (0.75 . (120 206 163))
                   (0.88 . (187 230 172))
                   (1.00 . (253 254 204))))
    (cdom . ((0.00 . (47  15  62 ))
             (0.13 . (87  23  86 ))
             (0.25 . (130 28  99 ))
             (0.38 . (171 41  96 ))
             (0.50 . (206 67  86 ))
             (0.63 . (230 106 84 ))
             (0.75 . (242 149 103))
             (0.88 . (249 193 135))
             (1.00 . (254 237 176))))
    (chlorophyll . ((0.00 . (18  36  20 ))
                    (0.13 . (25  63  41 ))
                    (0.25 . (24  91  59 ))
                    (0.38 . (13  119 72 ))
                    (0.50 . (18  148 80 ))
                    (0.63 . (80  173 89 ))
                    (0.75 . (132 196 122))
                    (0.88 . (175 221 162))
                    (1.00 . (215 249 208))))
    (density . ((0.00 . (54  14  36 ))
                (0.13 . (89  23  80 ))
                (0.25 . (110 45  132))
                (0.38 . (120 77  178))
                (0.50 . (120 113 213))
                (0.63 . (115 151 228))
                (0.75 . (134 185 227))
                (0.88 . (177 214 227))
                (1.00 . (230 241 241))))
    (freesurface-blue . ((0.00 . (30  4   110))
                         (0.13 . (47  14  176))
                         (0.25 . (41  45  236))
                         (0.38 . (25  99  212))
                         (0.50 . (68  131 200))
                         (0.63 . (114 156 197))
                         (0.75 . (157 181 203))
                         (0.88 . (200 208 216))
                         (1.00 . (241 237 236))))
    (freesurface-red . ((0.00 . (60  9   18 ))
                        (0.13 . (100 17  27 ))
                        (0.25 . (142 20  29 ))
                        (0.38 . (177 43  27 ))
                        (0.50 . (192 87  63 ))
                        (0.63 . (205 125 105))
                        (0.75 . (216 162 148))
                        (0.88 . (227 199 193))
                        (1.00 . (241 237 236))))
    (oxygen . ((0.00 . (64  5   5  ))
               (0.13 . (106 6   15 ))
               (0.25 . (144 26  7  ))
               (0.38 . (168 64  3  ))
               (0.50 . (188 100 4  ))
               (0.63 . (206 136 11 ))
               (0.75 . (220 174 25 ))
               (0.88 . (231 215 44 ))
               (1.00 . (248 254 105))))
    (par . ((0.00 . (51  20  24 ))
            (0.13 . (90  32  35 ))
            (0.25 . (129 44  34 ))
            (0.38 . (159 68  25 ))
            (0.50 . (182 99  19 ))
            (0.63 . (199 134 22 ))
            (0.75 . (212 171 35 ))
            (0.88 . (221 210 54 ))
            (1.00 . (225 253 75 ))))
    (phase . ((0.00 . (145 105 18 ))
              (0.13 . (184 71  38 ))
              (0.25 . (186 58  115))
              (0.38 . (160 71  185))
              (0.50 . (110 97  218))
              (0.63 . (50  123 164))
              (0.75 . (31  131 110))
              (0.88 . (77  129 34 ))
              (1.00 . (145 105 18 ))))
    (salinity . ((0.00 . (42  24  108))
                 (0.13 . (33  50  162))
                 (0.25 . (15  90  145))
                 (0.38 . (40  118 137))
                 (0.50 . (59  146 135))
                 (0.63 . (79  175 126))
                 (0.75 . (120 203 104))
                 (0.88 . (193 221 100))
                 (1.00 . (253 239 154))))
    (temperature . ((0.00 . (4   35  51 ))
                    (0.13 . (23  51  122))
                    (0.25 . (85  59  157))
                    (0.38 . (129 79  143))
                    (0.50 . (175 95  130))
                    (0.63 . (222 112 101))
                    (0.75 . (249 146 66 ))
                    (0.88 . (249 196 65 ))
                    (1.00 . (232 250 91 ))))
    (velocity-blue . ((0.00 . (17  32  64 ))
                      (0.13 . (35  52  116))
                      (0.25 . (29  81  156))
                      (0.38 . (31  113 162))
                      (0.50 . (50  144 169))
                      (0.63 . (87  173 176))
                      (0.75 . (149 196 189))
                      (0.88 . (203 221 211))
                      (1.00 . (254 251 230))))
    (velocity-green . ((0.00 . (23  35  19 ))
                       (0.13 . (24  64  38 ))
                       (0.25 . (11  95  45 ))
                       (0.38 . (39  123 35 ))
                       (0.50 . (95  146 12 ))
                       (0.63 . (152 165 18 ))
                       (0.75 . (201 186 69 ))
                       (0.88 . (233 216 137))
                       (1.00 . (255 253 205))))
    (cubehelix . ((0.00 . (0   0   0  ))
                  (0.07 . (22  5   59 ))
                  (0.13 . (60  4   105))
                  (0.20 . (109 1   135))
                  (0.27 . (161 0   147))
                  (0.33 . (210 2   142))
                  (0.40 . (251 11  123))
                  (0.47 . (255 29  97 ))
                  (0.53 . (255 54  69 ))
                  (0.60 . (255 85  46 ))
                  (0.67 . (255 120 34 ))
                  (0.73 . (255 157 37 ))
                  (0.80 . (241 191 57 ))
                  (0.87 . (224 220 93 ))
                  (0.93 . (218 241 142))
                  (1.00 . (227 253 198)))))
  "Color map definitions.")

(defun colormaps-interpolate (value cmap-lo cmap-hi)
  "Interpolate the given VALUE using given colormaps ranges CMAP-LO and CMAP-HI."
  (pcase (list cmap-lo cmap-hi)
    (`((,val-lo . ,color-lo) (,val-hi . ,color-hi))
     (let ((val-pos (/ (- value val-lo) (float (- val-hi val-lo)))))
       (cl-mapcar (lambda (c1 c2) (round (+ c1 c2)))
                  (mapcar (lambda (x) (* x (- 1 val-pos))) color-lo)
                  (mapcar (lambda (x) (* x val-pos)) color-hi))))))

(defun colormaps-get-def-range (value cmap &optional defs prev)
  "Get lower and upper color definition for VALUE using CMAP.
Optional args DEFS and PREV are for recursion."
  (cl-assert (and (>= value 0.0) (<= value 1.0)) nil "Value not in range [0.0, 1.0]")
  (if (null defs)
      (colormaps-get-def-range value cmap (cdr cmap) (car cmap))
    (let ((current (car defs)))
      (if (>= (car current) value)
          (cons prev current)
        (colormaps-get-def-range value cmap (cdr defs) current)))))

;;;###autoload
(defun colormaps-get-color (value &optional cmap-id)
  "Get hex color for given VALUE and CMAP-ID (identifier symbol for colormap)."
  (pcase (colormaps-get-def-range value (alist-get (or cmap-id 'viridis) colormaps-cmaps))
    (`(,cmap-lo . ,cmap-hi)
     (apply #'color-rgb-to-hex (mapcar (lambda (x) (/ x 255.0)) (colormaps-interpolate value cmap-lo cmap-hi))))))

(provide 'colormaps)
;;; colormaps.el ends here
