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

!--------------------------------------------------------------------------------------------------
! S40RTS
!
! 3D mantle model S40RTS [Ritsema et al., 2010]
!
! Note that S40RTS uses transversely isotropic PREM as a background
! model, and that we use the PREM radial attenuation model when ATTENUATION is incorporated.
!
! reference:
!     J. Ritsema, A. Deuss, H.J. van Heijst and J.H. Woodhouse, 2010.
!     S40RTS: a degree-40 shear-velocity model for the mantle from new Rayleigh wave dispersion,
!     teleseismic traveltime and normal-mode splitting function measurements.
!     Geophys. J. Int., DOI: 10.1111/j.1365-246X.2010.04884.x
!
!
! email notes from Jeroen Ritsema (2010) about the implementation:
! "
! Good idea to include more models!
!
! I have attached our s40rts model. It is parameterized up to spherical harmonic order 40
! but the vertical parametrization is exactly the same as used in s20rts.
! So, it should be easy to implement it.
!
! Like s20, s40 is referenced to the (anisotropic) prem model and contains only Vs perturbations.
! We use a 0.5 dVs versus drho scaling factor but density is not inverted for.
! For dVp I suggest you use the P12 or P20 model that Jeroen T already has.
! "
!
!--------------------------------------------------------------------------------------------------

  module model_s40rts_par

  ! three_d_mantle_model_constants
  integer, parameter :: NK_20 = 20
  integer, parameter :: NS_40 = 40

  ! model_s40rts_variables
  !a = positive m  (radial, theta, phi) --> (k,l,m) (maybe other way around??)
  !b = negative m  (radial, theta, phi) --> (k,l,-m)
  double precision,dimension(:,:,:),allocatable :: &
    S40RTS_V_dvs_a,S40RTS_V_dvs_b,S40RTS_V_dvp_a,S40RTS_V_dvp_b

  ! splines
  double precision,dimension(:),allocatable :: S40RTS_V_spknt
  double precision,dimension(:,:),allocatable :: S40RTS_V_qq0
  double precision,dimension(:,:,:),allocatable :: S40RTS_V_qq

  end module model_s40rts_par

!
!--------------------------------------------------------------------------------------------------
!

  subroutine model_s40rts_broadcast()

! standard routine to setup model

  use constants
  use model_s40rts_par

  implicit none

  ! local parameters
  integer :: ier

  ! user info
  if (myrank == 0) then
    write(IMAIN,*) 'broadcast model: S40RTS'
    call flush_IMAIN()
  endif

  allocate(S40RTS_V_dvs_a(0:NK_20,0:NS_40,0:NS_40), &
           S40RTS_V_dvs_b(0:NK_20,0:NS_40,0:NS_40), &
           S40RTS_V_dvp_a(0:NK_20,0:NS_40,0:NS_40), &
           S40RTS_V_dvp_b(0:NK_20,0:NS_40,0:NS_40), &
           S40RTS_V_spknt(NK_20+1), &
           S40RTS_V_qq0(NK_20+1,NK_20+1), &
           S40RTS_V_qq(3,NK_20+1,NK_20+1), &
           stat=ier)
  if (ier /= 0 ) call exit_MPI(myrank,'Error allocating S40RTS_V arrays')

  ! the variables read are declared and stored in structure S40RTS_V
  if (myrank == 0) call read_model_s40rts()

  ! broadcast the information read on the main node to all the nodes
  call bcast_all_dp(S40RTS_V_dvs_a,(NK_20+1)*(NS_40+1)*(NS_40+1))
  call bcast_all_dp(S40RTS_V_dvs_b,(NK_20+1)*(NS_40+1)*(NS_40+1))
  call bcast_all_dp(S40RTS_V_dvp_a,(NK_20+1)*(NS_40+1)*(NS_40+1))
  call bcast_all_dp(S40RTS_V_dvp_b,(NK_20+1)*(NS_40+1)*(NS_40+1))
  call bcast_all_dp(S40RTS_V_spknt,NK_20+1)
  call bcast_all_dp(S40RTS_V_qq0,(NK_20+1)*(NK_20+1))
  call bcast_all_dp(S40RTS_V_qq,3*(NK_20+1)*(NK_20+1))

  end subroutine model_s40rts_broadcast
!
!-------------------------------------------------------------------------------------------------
!

  subroutine read_model_s40rts()

  use constants
  use model_s40rts_par

  implicit none

  ! local parameters
  integer :: k,l,m,ier
  character(len=*), parameter :: S40RTS = 'DATA/s40rts/S40RTS.dat'
  character(len=*), parameter :: P12 = 'DATA/s20rts/P12.dat'    !model P12 is in s20rts data directory

  ! S40RTS degree 40 S model from Ritsema
  open(unit=IIN,file=trim(S40RTS),status='old',action='read',iostat=ier)
  if (ier /= 0) then
    write(IMAIN,*) 'Error opening "', trim(S40RTS), '": ', ier
    call flush_IMAIN()
    ! stop
    call exit_MPI(0, 'Error: opening model s40rts data file DATA/s40rts/S40RTS.dat failed, please check...')
  endif

  do k = 0,NK_20
    do l = 0,NS_40
      read(IIN,*) S40RTS_V_dvs_a(k,l,0),(S40RTS_V_dvs_a(k,l,m),S40RTS_V_dvs_b(k,l,m),m = 1,l)
    enddo
  enddo
  close(IIN)

  ! P12 degree 12 P model from Ritsema
  open(unit=IIN,file=trim(P12),status='old',action='read',iostat=ier)
  if (ier /= 0) then
    write(IMAIN,*) 'Error opening "', trim(P12), '": ', ier
    call exit_MPI(0, 'Error : opening model s40rts data file DATA/s20rts/P12.dat failed, please check...')
  endif
  do k = 0,NK_20
    do l=0,12
      read(IIN,*) S40RTS_V_dvp_a(k,l,0),(S40RTS_V_dvp_a(k,l,m),S40RTS_V_dvp_b(k,l,m),m = 1,l)
    enddo
    do l=13,NS_40
      S40RTS_V_dvp_a(k,l,0) = 0.0d0
      do m = 1,l
        S40RTS_V_dvp_a(k,l,m) = 0.0d0
        S40RTS_V_dvp_b(k,l,m) = 0.0d0
      enddo
    enddo
  enddo
  close(IIN)

  ! set up the splines used as radial basis functions by Ritsema
  call s40rts_splhsetup()

  end subroutine read_model_s40rts

!---------------------------

  subroutine mantle_s40rts(radius,theta,phi,dvs,dvp,drho)

  use constants, only: EARTH_R

  use shared_parameters, only: MODEL_NAME

  use model_s40rts_par

  implicit none

  double precision, intent(in) :: radius,theta,phi
  double precision, intent(inout) :: dvs,dvp,drho

  ! local parameters
  ! factor to convert perturbations in shear speed to perturbations in density
  ! (see comments in s20rts model about this factor)
  double precision, parameter :: SCALE_RHO = 0.40d0

  ! factor to convert perturbations as mentioned in S40RTS paper version (section 3.1, p.1226):
  ! dvp
  double precision, parameter :: SCALE_VP_MAX_PAPER = 1.d0/2.d0  ! at surface: dln(vs)/dln(vp) = 2 - > dln(vp) = 1/2 dln(vs)
  double precision, parameter :: SCALE_VP_MIN_PAPER = 1.d0/3.d0  ! at CMB:     dln(vs)/dln(vp) = 3 - > dln(vp) = 1/3 dln(vs)
  ! drho
  double precision, parameter :: SCALE_RHO_PAPER = 0.50d0

  double precision, parameter :: R_EARTH_ = EARTH_R          ! 6371000.d0
  double precision, parameter :: RMOHO_ = EARTH_R - 24400.d0 ! 6346600.d0  using a PREM crustal thickness of 24.4 km
  double precision, parameter :: RCMB_ = 3480000.d0
  double precision, parameter :: ZERO_ = 0.d0

  integer :: l,m,k
  double precision :: r_moho,r_cmb,xr
  double precision :: dvs_alm,dvs_blm
  double precision :: dvp_alm,dvp_blm
  double precision :: s40rts_rsple,radial_basis(0:NK_20)
  double precision :: sint,cost,x(2*NS_40+1),dx(2*NS_40+1)
  double precision :: fac

  dvs = ZERO_
  dvp = ZERO_
  drho = ZERO_

  ! normalized radii
  r_moho = RMOHO_ / R_EARTH_     ! mantle model top
  r_cmb = RCMB_ / R_EARTH_       ! mantle model bottom
  if (radius >= r_moho .or. radius <= r_cmb) return

  ! scaled radius between [-1,1]
  xr = -1.0d0+2.0d0*(radius-r_cmb)/(r_moho-r_cmb)
  if (xr > 1.0) print *,'xr > 1.0'
  if (xr < -1.0) print *,'xr < -1.0'

  ! contributions from vertical splines
  do k = 0,NK_20
    radial_basis(k) = s40rts_rsple(1,NK_20+1,S40RTS_V_spknt(1),S40RTS_V_qq0(1,NK_20+1-k),S40RTS_V_qq(1,1,NK_20+1-k),xr)
  enddo

  ! spherical harmonics
  do l = 0,NS_40
    sint = dsin(theta)
    cost = dcos(theta)
    call lgndr(l,cost,sint,x,dx)

    dvs_alm = 0.0d0
    dvp_alm = 0.0d0
    do k = 0,NK_20
      dvs_alm = dvs_alm+radial_basis(k)*S40RTS_V_dvs_a(k,l,0)
      dvp_alm = dvp_alm+radial_basis(k)*S40RTS_V_dvp_a(k,l,0)
    enddo
    dvs = dvs+dvs_alm*x(1)
    dvp = dvp+dvp_alm*x(1)

    do m = 1,l
      dvs_alm = 0.0d0
      dvp_alm = 0.0d0
      dvs_blm = 0.0d0
      dvp_blm = 0.0d0
      do k = 0,NK_20
        dvs_alm = dvs_alm+radial_basis(k)*S40RTS_V_dvs_a(k,l,m)
        dvp_alm = dvp_alm+radial_basis(k)*S40RTS_V_dvp_a(k,l,m)
        dvs_blm = dvs_blm+radial_basis(k)*S40RTS_V_dvs_b(k,l,m)
        dvp_blm = dvp_blm+radial_basis(k)*S40RTS_V_dvp_b(k,l,m)
      enddo
      dvs = dvs+(dvs_alm*dcos(dble(m)*phi)+dvs_blm*dsin(dble(m)*phi))*x(m+1)
      dvp = dvp+(dvp_alm*dcos(dble(m)*phi)+dvp_blm*dsin(dble(m)*phi))*x(m+1)
    enddo

  enddo

  ! we have "MODEL  = s40rts" as the version suggested by Jeroen Ritsema,
  !     and "MODEL  = s40rts_paper" as the version with the same scaling factors as mentioned in the paper.
  !
  if (trim(MODEL_NAME) == 's40rts_paper') then
    ! original paper version of s40rts
    ! (there is no need for the P12 model in this case, perturbations are added to PREM)

    ! constant drho scaling
    ! density perturbations
    drho = SCALE_RHO_PAPER * dvs

    ! scales dvp
    ! linear scaling from top to bottom
    ! scaled radius between [0,1]
    xr = (radius-r_cmb)/(r_moho-r_cmb)
    fac = SCALE_VP_MIN_PAPER + xr * (SCALE_VP_MAX_PAPER - SCALE_VP_MIN_PAPER)

    ! makes sure to stay within min/max bounds
    if (fac < SCALE_VP_MIN_PAPER) fac = SCALE_VP_MIN_PAPER
    if (fac > SCALE_VP_MAX_PAPER) fac = SCALE_VP_MAX_PAPER

    !debug
    !print *,'debug: s40rts scaling fac ',fac,'radius',radius,xr,'depth',(1.0-radius)*R_EARTH_ / 1000.d0,'(km)'

    ! scaled dvp, overrides the previous dvp value
    dvp = fac * dvs

  else
    ! suggested version
    ! dvp based on P12 model
    ! density perturbations based on Karato/Masters/etc. (for a thermal, anelastic mantle)
    drho = SCALE_RHO * dvs

  endif

  end subroutine mantle_s40rts

!----------------------------------

  subroutine s40rts_splhsetup()

  use model_s40rts_par

  implicit none

  ! local parameters
  integer :: i,j
  double precision :: qqwk(3,NK_20+1)

  S40RTS_V_spknt(1) = -1.00000d0
  S40RTS_V_spknt(2) = -0.78631d0
  S40RTS_V_spknt(3) = -0.59207d0
  S40RTS_V_spknt(4) = -0.41550d0
  S40RTS_V_spknt(5) = -0.25499d0
  S40RTS_V_spknt(6) = -0.10909d0
  S40RTS_V_spknt(7) = 0.02353d0
  S40RTS_V_spknt(8) = 0.14409d0
  S40RTS_V_spknt(9) = 0.25367d0
  S40RTS_V_spknt(10) = 0.35329d0
  S40RTS_V_spknt(11) = 0.44384d0
  S40RTS_V_spknt(12) = 0.52615d0
  S40RTS_V_spknt(13) = 0.60097d0
  S40RTS_V_spknt(14) = 0.66899d0
  S40RTS_V_spknt(15) = 0.73081d0
  S40RTS_V_spknt(16) = 0.78701d0
  S40RTS_V_spknt(17) = 0.83810d0
  S40RTS_V_spknt(18) = 0.88454d0
  S40RTS_V_spknt(19) = 0.92675d0
  S40RTS_V_spknt(20) = 0.96512d0
  S40RTS_V_spknt(21) = 1.00000d0

  do i = 1,NK_20+1
    do j = 1,NK_20+1
      if (i == j) then
        S40RTS_V_qq0(j,i)=1.0d0
      else
        S40RTS_V_qq0(j,i)=0.0d0
      endif
    enddo
  enddo
  do i = 1,NK_20+1
    call s40rts_rspln(1,NK_20+1,S40RTS_V_spknt(1),S40RTS_V_qq0(1,i),S40RTS_V_qq(1,1,i),qqwk(1,1))
  enddo

  end subroutine s40rts_splhsetup

!----------------------------------

! changed the obsolescent f77 features in the two routines below
! now still awful Fortran, but at least conforms to f90 standard

  double precision function s40rts_rsple(I1,I2,X,Y,Q,S)

  implicit none

! rsple returns the value of the function y(x) evaluated at point S
! using the cubic spline coefficients computed by rspln and saved in Q.
! If S is outside the interval (x(i1),x(i2)) rsple extrapolates
! using the first or last interpolation polynomial. The arrays must
! be dimensioned at least - x(i2), y(i2), and q(3,i2).

      integer i1,i2
      double precision  X(*),Y(*),Q(3,*),s

      integer i,ii
      double precision h

      i = 1
      II=I2-1

!   GUARANTEE I WITHIN BOUNDS.
      I=MAX0(I,I1)
      I=MIN0(I,II)

!   SEE IF X IS INCREASING OR DECREASING.
      if (X(I2)-X(I1) < 0) goto 1
      if (X(I2)-X(I1) >= 0) goto 2

!   X IS DECREASING.  CHANGE I AS NECESSARY.
 1    if (S-X(I) <= 0) goto 3
      if (S-X(I) > 0) goto 4

 4    I=I-1

      if (I-I1 < 0) goto 11
      if (I-I1 == 0) goto 6
      if (I-I1 > 0) goto 1

 3    if (S-X(I+1) < 0) goto 5
      if (S-X(I+1) >= 0) goto 6

 5    I=I+1

      if (I-II < 0) goto 3
      if (I-II == 0) goto 6
      if (I-II > 0) goto 7

!   X IS INCREASING.  CHANGE I AS NECESSARY.
 2    if (S-X(I+1) <= 0) goto 8
      if (S-X(I+1) > 0) goto 9

 9    I=I+1

      if (I-II < 0) goto 2
      if (I-II == 0) goto 6
      if (I-II > 0) goto 7

 8    if (S-X(I) < 0) goto 10
      if (S-X(I) >= 0) goto 6

 10   I=I-1
      if (I-I1 < 0) goto 11
      if (I-I1 == 0) goto 6
      if (I-I1 > 0) goto 8

 7    I=II
      goto 6
 11   I=I1

!   CALCULATE RSPLE USING SPLINE COEFFICIENTS IN Y AND Q.
 6    H=S-X(I)
      S40RTS_RSPLE=Y(I)+H*(Q(1,I)+H*(Q(2,I)+H*Q(3,I)))

      end function s40rts_rsple

!----------------------------------

  subroutine s40rts_rspln(I1,I2,X,Y,Q,F)

  implicit none

! The subroutine rspln computes cubic spline interpolation coefficients
! for y(x) between grid points i1 and i2 saving them in q.The
! interpolation is continuous with continuous first and second
! derivatives. It agrees exactly with y at grid points and with the
! three point first derivatives at both end points (i1 and i2).
! X must be monotonic but if two successive values of x are equal
! a discontinuity is assumed and separate interpolation is done on
! each strictly monotonic segment. The arrays must be dimensioned at
! least - x(i2), y(i2), q(3,i2), and f(3,i2).
! F is working storage for rspln.

      integer i1,i2
      double precision X(*),Y(*),Q(3,*),F(3,*)

      integer i,j,k,j1,j2
      double precision y0,a0,b0,b1,h,h2,ha,h2a,h3a,h2b
      double precision YY(3),small
      equivalence (YY(1),Y0)
      data SMALL/1.0d-08/,YY/0.0d0,0.0d0,0.0d0/

      J1=I1+1
      Y0=0.0d0

!   BAIL OUT IF THERE ARE LESS THAN TWO POINTS TOTAL
      if (I2-I1 < 0) return
      if (I2-I1 == 0) goto 17
      if (I2-I1 > 0) goto 8

 8    A0=X(J1-1)
!   SEARCH FOR DISCONTINUITIES.
      DO 3 I=J1,I2
      B0=A0
      A0=X(I)
      if (DABS((A0-B0)/DMAX1(A0,B0)) < SMALL) goto 4
 3    continue
 17   J1=J1-1
      J2=I2-2
      goto 5
 4    J1=J1-1
      J2=I-3
!   SEE IF THERE ARE ENOUGH POINTS TO INTERPOLATE (AT LEAST THREE).
 5    if (J2+1-J1 < 0) goto 9
      if (J2+1-J1 == 0) goto 10
      if (J2+1-J1 > 0) goto 11

!   ONLY TWO POINTS.  USE LINEAR INTERPOLATION.
 10   J2=J2+2
      Y0=(Y(J2)-Y(J1))/(X(J2)-X(J1))
      DO J=1,3
        Q(J,J1)=YY(J)
        Q(J,J2)=YY(J)
      enddo
      goto 12

!   MORE THAN TWO POINTS.  DO SPLINE INTERPOLATION.
 11   A0 = 0.
      H=X(J1+1)-X(J1)
      H2=X(J1+2)-X(J1)
      Y0=H*H2*(H2-H)
      H=H*H
      H2=H2*H2
!   CALCULATE DERIVATIVE AT NEAR END.
      B0=(Y(J1)*(H-H2)+Y(J1+1)*H2-Y(J1+2)*H)/Y0
      B1=B0

!   EXPLICITLY REDUCE BANDED MATRIX TO AN UPPER BANDED MATRIX.
      DO I=J1,J2
        H=X(I+1)-X(I)
        Y0=Y(I+1)-Y(I)
        H2=H*H
        HA=H-A0
        H2A=H-2.0d0*A0
        H3A=2.0d0*H-3.0d0*A0
        H2B=H2*B0
        Q(1,I)=H2/HA
        Q(2,I)=-HA/(H2A*H2)
        Q(3,I)=-H*H2A/H3A
        F(1,I)=(Y0-H*B0)/(H*HA)
        F(2,I)=(H2B-Y0*(2.0d0*H-A0))/(H*H2*H2A)
        F(3,I)=-(H2B-3.0d0*Y0*HA)/(H*H3A)
        A0=Q(3,I)
        B0=F(3,I)
      enddo

!   TAKE CARE OF LAST TWO ROWS.
      I=J2+1
      H=X(I+1)-X(I)
      Y0=Y(I+1)-Y(I)
      H2=H*H
      HA=H-A0
      H2A=H*HA
      H2B=H2*B0-Y0*(2.0d0*H-A0)
      Q(1,I)=H2/HA
      F(1,I)=(Y0-H*B0)/H2A
      HA=X(J2)-X(I+1)
      Y0=-H*HA*(HA+H)
      HA=HA*HA

!   CALCULATE DERIVATIVE AT FAR END.
      Y0=(Y(I+1)*(H2-HA)+Y(I)*HA-Y(J2)*H2)/Y0
      Q(3,I)=(Y0*H2A+H2B)/(H*H2*(H-2.0d0*A0))
      Q(2,I)=F(1,I)-Q(1,I)*Q(3,I)

!   SOLVE UPPER BANDED MATRIX BY REVERSE ITERATION.
      DO J=J1,J2
        K=I-1
        Q(1,I)=F(3,K)-Q(3,K)*Q(2,I)
        Q(3,K)=F(2,K)-Q(2,K)*Q(1,I)
        Q(2,K)=F(1,K)-Q(1,K)*Q(3,K)
        I=K
      enddo
      Q(1,I)=B1
!   FILL IN THE LAST POINT WITH A LINEAR EXTRAPOLATION.
 9    J2=J2+2
      DO J=1,3
        Q(J,J2)=YY(J)
      enddo

!   SEE IF THIS DISCONTINUITY IS THE LAST.
 12   if (J2-I2 < 0) then
        goto 6
      else
        return
      endif

!   NO.  GO BACK FOR MORE.
 6    J1=J2+2
      if (J1-I2 <= 0) goto 8
      if (J1-I2 > 0) goto 7

!   THERE IS ONLY ONE POINT LEFT AFTER THE LATEST DISCONTINUITY.
 7    DO J=1,3
        Q(J,I2)=YY(J)
      enddo

      end subroutine s40rts_rspln

