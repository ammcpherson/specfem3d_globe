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
!
! based on scaling factors by Ishii et al. (2002)
!
! constant model given by Table 6 in:
!   Joint inversion of normal mode and body wave data for inner core anisotropy
!   1. Laterally homogeneous anisotropy, 2002.
!   Miaki Ishii, Jeroen Tromp, Adam M. Dziewonski, Goran Ekstrom
!   JGR Solid Earth, 107, B12, 2379.
!
! and for completeness, the joint paper:
!   Joint inversion of normal mode and body wave data for inner core anisotropy
!   2. Possible complexities, 2002.
!   Miaki Ishii, Adam M. Dziewonski, Jeroen Tromp, Goran Ekstrom
!   JGR Solid Earth, 107, B12. 2380.
!
!--------------------------------------------------------------------------------------------------

  subroutine model_aniso_inner_core(r,c11,c12,c13,c33,c44,REFERENCE_1D_MODEL, &
                                    vpv,vph,vsv,vsh,rho,eta_aniso)

  use constants
  use shared_parameters, only: R_PLANET,RHOAV

  implicit none

! given a normalized radius x, gives non-dimensionalized c11,c33,c12,c13,c44

  integer, intent(in) :: REFERENCE_1D_MODEL

  double precision, intent(in) :: r
  double precision, intent(inout) :: c11,c12,c13,c33,c44
  double precision, intent(inout) :: rho,vpv,vph,vsv,vsh,eta_aniso

  ! local parameters
  double precision :: vp,vs,rho_dim
  double precision :: vpc,vsc,rhoc
  double precision :: vp0,vs0,rho0,A0
  double precision :: c66
  double precision :: scaleval,scale_GPa
  double precision :: x
  double precision :: PREM2_RIC_UPPER

  logical, save :: is_first_call = .true.

  ! user output
  if (is_first_call) then
    is_first_call = .false.
    if (myrank == 0) then
      write(IMAIN,*)
      write(IMAIN,*) 'incorporating anisotropic inner core model: Ishii'
      write(IMAIN,*)
      call flush_IMAIN()
    endif
  endif

  ! non-dimensional radius (in m)
  x = r

  ! calculates isotropic values from given (transversely isotropic) reference values
  ! (are non-dimensionalized)
  vp = sqrt(((8.d0+4.d0*eta_aniso)*vph*vph + 3.d0*vpv*vpv &
            + (8.d0 - 8.d0*eta_aniso)*vsv*vsv)/15.d0)
  vs = sqrt(((1.d0-2.d0*eta_aniso)*vph*vph + vpv*vpv &
            + 5.d0*vsh*vsh + (6.d0+4.d0*eta_aniso)*vsv*vsv)/15.d0)

  ! scale to dimensions (e.g. used in prem model)
  scaleval = R_PLANET/1000.d0 * dsqrt(PI*GRAV*RHOAV)
  vp = vp * scaleval    ! km/s
  vs = vs * scaleval
  rho_dim = rho * RHOAV/1000.d0

  select case (REFERENCE_1D_MODEL)

    case (REFERENCE_MODEL_IASP91)
      ! values at center
      vp0 = 11.24094d0
      vs0 = 3.56454d0
      rho0 = 13.0885d0

      ! checks with input isotropic values
      vpc = vp0 - 4.09689d0*x*x
      vsc = vs0 - 3.45241d0*x*x
      rhoc = rho0 - 8.8381d0*x*x
      ! checks with given values
      if (abs(vpc-vp) > TINYVAL .or. abs(vsc-vs) > TINYVAL .or. abs(rhoc-rho_dim) > TINYVAL) then
        stop 'Error isotropic IASP91 values in model_aniso_inner_core() '
      endif

    case (REFERENCE_MODEL_PREM)
      ! values at center
      vp0 = 11.2622d0
      vs0 = 3.6678d0
      rho0 = 13.0885d0

      ! checks with input isotropic values
      vpc = vp0 - 6.3640d0*x*x
      vsc = vs0 - 4.4475d0*x*x
      rhoc = rho0 - 8.8381d0*x*x
      ! checks
      if (abs(vpc-vp) > TINYVAL .or. abs(vsc-vs) > TINYVAL .or. abs(rhoc-rho_dim) > TINYVAL) then
        stop 'Error isotropic PREM values in model_aniso_inner_core() '
      endif

    case (REFERENCE_MODEL_PREM2)
      ! values at center (same as PREM)
      vp0 = 11.2622d0
      vs0 = 3.6678d0
      rho0 = 13.0885d0

      ! checks with input isotropic values
      PREM2_RIC_UPPER = 1010000.d0     ! upper inner core at 1010 km radius
      if (x * R_PLANET <= PREM2_RIC_UPPER) then
        ! lower inner core, same value as PREM
        vpc = 11.2622d0 - 6.3640d0*x*x
      else
        ! upper inner core modification
        vpc = 11.3041d0 - 1.2730d0*x
      endif

      vsc = vs0 - 4.4475d0*x*x
      rhoc = rho0 - 8.8381d0*x*x

      ! checks
      if (abs(vpc-vp) > TINYVAL .or. abs(vsc-vs) > TINYVAL .or. abs(rhoc-rho_dim) > TINYVAL) then
        stop 'Error isotropic PREM2 values in model_aniso_inner_core() '
      endif

    case (REFERENCE_MODEL_1DREF)
      ! values at center
      vp0 = 11262.20 / 1000.0d0
      vs0 = 3667.800 / 1000.0d0
      rho0 = 13088.480 / 1000.0d0

    case (REFERENCE_MODEL_1066A)
      ! values at center
      vp0 = 11.33830d0
      vs0 = 3.62980d0
      rho0 = 13.429030d0

    case (REFERENCE_MODEL_AK135F_NO_MUD)
      ! values at center
      vp0 = 11.26220d0
      vs0 = 3.667800d0
      rho0 = 13.01220d0

    case (REFERENCE_MODEL_JP1D)
      ! values at center
      vp0 = 11.24094d0
      vs0 = 3.56454d0
      rho0 = 13.0885d0

    case (REFERENCE_MODEL_SEA1D)
      ! values at center
      vp0 = 11.240940d0
      vs0 = 3.564540d0
      rho0 = 13.012190d0

    case (REFERENCE_MODEL_CCREM)
      ! values at center
      vp0 = 11.2636d0
      vs0 = 3.6677d0
      rho0 = 13.0351d0

    case default
      stop 'unknown 1D reference Earth model in anisotropic inner core'

  end select

! elastic tensor for hexagonal symmetry in reduced notation:
!
!      c11 c12 c13  0   0        0
!      c12 c11 c13  0   0        0
!      c13 c13 c33  0   0        0
!       0   0   0  c44  0        0
!       0   0   0   0  c44       0
!       0   0   0   0   0  c66=(c11-c12)/2
!
!       in terms of the A, C, L, N and F of Love (1927):
!
!       c11 = A
!       c33 = C
!       c12 = A-2N
!       c13 = F
!       c44 = L
!       c66 = N
!
!       isotropic equivalent:
!
!       c11 = lambda+2mu
!       c33 = lambda+2mu
!       c12 = lambda
!       c13 = lambda
!       c44 = mu
!       c66 = mu

! Ishii et al. (2002): Table 6
!
! alpha = 3.490 % = (C-A)/A0    = (c33-c11)/A0
!  beta = 0.988 % = (L-N)/A0    = (c44-c66)/A0
! gamma = 0.881 % = (A-2N-F)/A0    = (c12-c13)/A0
! where A0 is A at the Earth's center
!
! assume c11 = lambda+2mu
!        c66 = (c11-c12)/2 = mu
!
! then   c33 = c11 + alpha*A0
!        c44 = c66 + beta*A0
!        c13 = c12 - gamma*A0
!        and c12 = c11 - 2*c66
!
! Note: The value vs0, while set above, is unnecessary for the
! calculation below.
!
! Steinle-Neumann (2002):
!
!  r    T    rho    c11   c12  c13  c33  c44 KS   mu
! (km) (K) (Mg/m3) (GPa)
! 0    5735 13.09   1693 1253 1364 1813 154 1457 184
! 200  5729 13.08   1689 1251 1362 1809 154 1455 184
! 400  5711 13.05   1676 1243 1353 1795 151 1444 181
! 600  5682 13.01   1661 1232 1341 1779 150 1432 180
! 800  5642 12.95   1638 1214 1321 1755 148 1411 178
! 1000 5590 12.87   1606 1190 1295 1720 146 1383 175
! 1200 5527 12.77   1559 1155 1257 1670 141 1343 169
!

! note: the symmetry axis aligns with the rotation axis of the Earth, which is assumed to be the vertical z-direction here.
!       thus, the reference system assumed here is the same as the SPECFEM reference,
!       and there is no need for rotating from a local (radial) to a global (SPECFEM) reference.

  c11 = (rho_dim * vp*vp)    ! in GPa
  c66 = (rho_dim * vs*vs)
  c12 = c11 - 2.0d0 * c66

  A0 = (rho0 * vp0*vp0)

  c33 = c11 + 0.0349d0 * A0
  c44 = c66 + 0.00988d0 * A0
  c13 = c12 - 0.00881d0 * A0

  ! non-dimensionalize the elastic coefficients using
  ! the scale of GPa--[g/cm^3][(km/s)^2]
  scaleval = dsqrt(PI*GRAV*RHOAV)
  scale_GPa = (RHOAV/1000.d0)*((R_PLANET*scaleval/1000.d0)**2)

  ! scales only values to return
  c11 = c11/scale_GPa
  c12 = c12/scale_GPa
  c13 = c13/scale_GPa
  c33 = c33/scale_GPa
  c44 = c44/scale_GPa

  ! re-converts cij to tiso (to store e.g. muvstore values)
  ! C11 = A = rho * vph**2
  ! C33 = C = rho * vpv**2
  ! C44 = L = rho * vsv**2
  ! C13 = F = eta * (A - 2*L)
  ! C12 = C11 - 2 C66 = A - 2*N = rho * (vph**2 - 2 * vsh**2)
  ! C22 = C11 = A
  ! C23 = C13 = F
  ! C55 = C44 = L
  ! C66 = N = rho * vsh**2 = (C11-C12)/2
  vpv = sqrt(c33/rho)
  vph = sqrt(c11/rho)
  vsv = sqrt(c44/rho)
  vsh = sqrt((c11-c12)/rho)
  eta_aniso = c13/(c11 - 2.d0*c44)

  end subroutine model_aniso_inner_core

