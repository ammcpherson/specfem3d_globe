!=====================================================================
!
!          S p e c f e m 3 D  G l o b e  V e r s i o n  8 . 0
!          --------------------------------------------------
!
!     Main historical authors: Dimitri Komatitsch and Jeroen Tromp
!                        Princeton University, USA
!                and CNRS / University of Marseille, France
!                 (there are currently many more authors!)
! (c) Princeton University and CNRS / University of Marseille, April 2014
!
! This program is free software; you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation; either version 3 of the License, or
! (at your option) any later version.
!
! This program is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License along
! with this program; if not, write to the Free Software Foundation, Inc.,
! 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
!
!=====================================================================

  subroutine define_derivation_matrices(xigll,yigll,zigll,wxgll,wygll,wzgll, &
                                        hprime_xx,hprime_yy,hprime_zz, &
                                        hprimewgll_xx,hprimewgll_yy,hprimewgll_zz, &
                                        wgllwgll_xy,wgllwgll_xz,wgllwgll_yz,wgll_cube)

  use constants

  implicit none

! Gauss-Lobatto-Legendre points of integration and weights
  double precision, dimension(NGLLX),intent(out) :: xigll,wxgll
  double precision, dimension(NGLLY),intent(out) :: yigll,wygll
  double precision, dimension(NGLLZ),intent(out) :: zigll,wzgll

! array with derivatives of Lagrange polynomials and precalculated products
  real(kind=CUSTOM_REAL), dimension(NGLLX,NGLLX),intent(out) :: hprime_xx,hprimewgll_xx
  real(kind=CUSTOM_REAL), dimension(NGLLY,NGLLY),intent(out) :: hprime_yy,hprimewgll_yy
  real(kind=CUSTOM_REAL), dimension(NGLLZ,NGLLZ),intent(out) :: hprime_zz,hprimewgll_zz
  real(kind=CUSTOM_REAL), dimension(NGLLX,NGLLY),intent(out) :: wgllwgll_xy
  real(kind=CUSTOM_REAL), dimension(NGLLX,NGLLZ),intent(out) :: wgllwgll_xz
  real(kind=CUSTOM_REAL), dimension(NGLLY,NGLLZ),intent(out) :: wgllwgll_yz

! array with all the weights in the cube
  real(kind=CUSTOM_REAL), dimension(NGLLX,NGLLY,NGLLZ),intent(out) :: wgll_cube

! function for calculating derivatives of Lagrange polynomials
  double precision, external :: lagrange_deriv_GLL

  ! local parameters
  integer :: i,j,k,i1,i2,j1,j2,k1,k2

! set up coordinates of the Gauss-Lobatto-Legendre points
  call zwgljd(xigll,wxgll,NGLLX,GAUSSALPHA,GAUSSBETA)
  call zwgljd(yigll,wygll,NGLLY,GAUSSALPHA,GAUSSBETA)
  call zwgljd(zigll,wzgll,NGLLZ,GAUSSALPHA,GAUSSBETA)

! calculate derivatives of the Lagrange polynomials
! and precalculate some products in double precision
! hprime(i,j) = h'_j(xigll_i) by definition of the derivation matrix
  do i1 = 1,NGLLX
    do i2 = 1,NGLLX
      hprime_xx(i2,i1) = real(lagrange_deriv_GLL(i1-1,i2-1,xigll,NGLLX), kind=CUSTOM_REAL)
      hprimewgll_xx(i2,i1) = real(lagrange_deriv_GLL(i1-1,i2-1,xigll,NGLLX)*wxgll(i2), kind=CUSTOM_REAL)
    enddo
  enddo

  do j1 = 1,NGLLY
    do j2 = 1,NGLLY
      hprime_yy(j2,j1) = real(lagrange_deriv_GLL(j1-1,j2-1,yigll,NGLLY), kind=CUSTOM_REAL)
      hprimewgll_yy(j2,j1) = real(lagrange_deriv_GLL(j1-1,j2-1,yigll,NGLLY)*wygll(j2), kind=CUSTOM_REAL)
    enddo
  enddo

  do k1 = 1,NGLLZ
    do k2 = 1,NGLLZ
      hprime_zz(k2,k1) = real(lagrange_deriv_GLL(k1-1,k2-1,zigll,NGLLZ), kind=CUSTOM_REAL)
      hprimewgll_zz(k2,k1) = real(lagrange_deriv_GLL(k1-1,k2-1,zigll,NGLLZ)*wzgll(k2), kind=CUSTOM_REAL)
    enddo
  enddo

  do i = 1,NGLLX
    do j = 1,NGLLY
      wgllwgll_xy(i,j) = real(wxgll(i)*wygll(j), kind=CUSTOM_REAL)
    enddo
  enddo

  do i = 1,NGLLX
    do k = 1,NGLLZ
      wgllwgll_xz(i,k) = real(wxgll(i)*wzgll(k), kind=CUSTOM_REAL)
    enddo
  enddo

  do j = 1,NGLLY
    do k = 1,NGLLZ
      wgllwgll_yz(j,k) = real(wygll(j)*wzgll(k), kind=CUSTOM_REAL)
    enddo
  enddo

  do i = 1,NGLLX
    do j = 1,NGLLY
      do k = 1,NGLLZ
        wgll_cube(i,j,k) = wxgll(i)*wygll(j)*wzgll(k)
      enddo
    enddo
  enddo

  end subroutine define_derivation_matrices

