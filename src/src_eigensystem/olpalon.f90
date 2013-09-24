!
!
!
! Copyright (C) 2002-2005 J. K. Dewhurst, S. Sharma and C. Ambrosch-Draxl.
! This file is distributed under the terms of the GNU General Public License.
! See the file COPYING for license details.
!
!
Subroutine olpalon (overlap, is, ia, ngp, apwalm)
      Use modmain
      Use modfvsystem
      Implicit None
! arguments
      Type (HermitianMatrix) :: overlap
      Integer, Intent (In) :: is
      Integer, Intent (In) :: ia
      Integer, Intent (In) :: ngp
      Complex (8), Intent (In) :: apwalm (ngkmax, apwordmax, lmmaxapw, &
     & natmtot)
!
!
! local variables
      Integer :: ias, ilo, io, l, m, lm, i, j, k
      Complex (8) zsum, zv(ngp)
      ias = idxas (ia, is)
      Do ilo = 1, nlorb (is)
         l = lorbl (ilo, is)
         Do m = - l, l
            lm = idxlm (l, m)
            j = ngp + idxlo (lm, ilo, ias)
! calculate the matrix elements
            zv(:)=dcmplx(0d0,0d0)
            Do io = 1, apword (l, is)
              zv(:) = zv(:) + apwalm(:, io, lm, ias) * oalo (io, ilo, ias)
            End Do
            overlap%za(1:ngp,j)=overlap%za(1:ngp,j)+conjg(zv(:))
            overlap%za(j,1:ngp)=overlap%za(j,1:ngp)+zv(:)
         End Do
      End Do
      Return
End Subroutine
