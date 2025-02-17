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
!       Jean-Paul Montagner, January 2002
!       modified by Min Chen, Caltech, February 2002
!
!  input is (r, theta, phi), output is the matrix cij(6x6)
!  0 <= r <= 1, 0 <= theta <= pi, 0 <= phi <= 2 pi
!
!  returns non-dimensionalized cij
!
!  creates parameters p(i=1,14,r,theta,phi)
!  from model glob-prem3sm01 globpreman3sm01 (Montagner, 2002)
!
!--------------------------------------------------------------------------------------------------

  module model_aniso_mantle_par

  ! model_aniso_mantle_variables
  double precision,dimension(:,:,:,:),allocatable :: AMM_V_beta
  double precision,dimension(:),allocatable :: AMM_V_pro
  integer :: AMM_V_npar1

  end module model_aniso_mantle_par

!
!--------------------------------------------------------------------------------------------------
!

  subroutine model_aniso_mantle_broadcast()

! standard routine to setup model

  use constants, only: myrank,IMAIN
  use model_aniso_mantle_par

  implicit none

  ! local parameters
  integer :: ier

  ! user info
  if (myrank == 0) then
    write(IMAIN,*) 'broadcast model: 3d_anisotropic (aniso_mantle) model'
    call flush_IMAIN()
  endif

  ! allocates model arrays
  allocate(AMM_V_beta(14,34,37,73), &
           AMM_V_pro(47),stat=ier)
  if (ier /= 0 ) call exit_MPI(myrank,'Error allocating AMM_V arrays')

  ! the variables read are declared and stored in structure AMM_V
  if (myrank == 0) call read_aniso_mantle_model()

  ! broadcast the information read on the main to the nodes
  call bcast_all_singlei(AMM_V_npar1)
  call bcast_all_dp(AMM_V_beta,14*34*37*73)
  call bcast_all_dp(AMM_V_pro,47)

  end subroutine model_aniso_mantle_broadcast

!
!-------------------------------------------------------------------------------------------------
!

  subroutine model_aniso_mantle(r,theta,phi,vpv,vph,vsv,vsh,eta_aniso,rho, &
                                c11,c12,c13,c14,c15,c16,c22,c23,c24,c25,c26, &
                                c33,c34,c35,c36,c44,c45,c46,c55,c56,c66)

  use constants, only: DEGREES_TO_RADIANS
  use shared_parameters, only: R_PLANET,R670

  use model_aniso_mantle_par

  implicit none

  double precision,intent(in) :: r,theta,phi
  double precision,intent(in) :: vpv,vph,vsv,vsh,eta_aniso
  double precision,intent(inout) :: rho
  double precision,intent(out) :: c11,c12,c13,c14,c15,c16,c22,c23,c24,c25,c26, &
                                  c33,c34,c35,c36,c44,c45,c46,c55,c56,c66

  ! local parameters
  double precision :: d11,d12,d13,d14,d15,d16,d22,d23,d24,d25,d26, &
                      d33,d34,d35,d36,d44,d45,d46,d55,d56,d66

  double precision :: colat,lon
  double precision :: vp,vs

! uncomment this line to suppress the anisotropic mantle model
! call exit_MPI_without_rank('please provide an anisotropic mantle model for subroutine aniso_mantle_model')

  ! Montagner 2002, model
  !
  ! anisotropic model defined between Moho and 670 km
  ! (change to CMB if desired)
  if (r <= R670/R_PLANET) then
    ! takes reference model (PREM) velocity values and converts to full cij

    ! calculates isotropic values from given (transversely isotropic) reference values
    ! (are non-dimensionalized)
    !
    ! note: in case vpv == vph and vsv == vsh and eta == 1,
    !       this reduces to vp == vpv and vs == vsv
    vp = sqrt( ((8.d0+4.d0*eta_aniso)*vph*vph + 3.d0*vpv*vpv &
              + (8.d0 - 8.d0*eta_aniso)*vsv*vsv)/15.d0 )
    vs = sqrt( ((1.d0-2.d0*eta_aniso)*vph*vph + vpv*vpv &
                      + 5.d0*vsh*vsh + (6.d0+4.d0*eta_aniso)*vsv*vsv)/15.d0 )

    ! fills the rest of the mantle with the isotropic model
    c11 = rho*vp*vp
    c12 = rho*(vp*vp-2.d0*vs*vs)
    c13 = c12
    c14 = 0.d0
    c15 = 0.d0
    c16 = 0.d0
    c22 = c11
    c23 = c12
    c24 = 0.d0
    c25 = 0.d0
    c26 = 0.d0
    c33 = c11
    c34 = 0.d0
    c35 = 0.d0
    c36 = 0.d0
    c44 = rho*vs*vs
    c45 = 0.d0
    c46 = 0.d0
    c55 = c44
    c56 = 0.d0
    c66 = c44
  else
    ! above 670 discontinuity
    !
    ! converts colat/lon to degrees
    lon = phi / DEGREES_TO_RADIANS
    colat = theta / DEGREES_TO_RADIANS

    ! assign the local (d_ij) or global (c_ij) anisotropic parameters.
    ! The c_ij are the coefficients in the global
    ! reference frame used in SPECFEM3D.
    call build_cij(AMM_V_pro,AMM_V_npar1,rho,AMM_V_beta,r,colat,lon, &
                   d11,d12,d13,d14,d15,d16,d22,d23,d24,d25,d26,d33,d34,d35,d36, &
                   d44,d45,d46,d55,d56,d66)

    call rotate_tensor_radial_to_global(theta,phi,d11,d12,d13,d14,d15,d16,d22,d23,d24,d25,d26, &
                                        d33,d34,d35,d36,d44,d45,d46,d55,d56,d66, &
                                        c11,c12,c13,c14,c15,c16,c22,c23,c24,c25,c26, &
                                        c33,c34,c35,c36,c44,c45,c46,c55,c56,c66)
  endif

  end subroutine model_aniso_mantle

!--------------------------------------------------------------------

  subroutine build_cij(pro,npar1,rho,beta,r,colat,lon, &
                       d11,d12,d13,d14,d15,d16,d22,d23,d24,d25,d26,d33,d34,d35,d36, &
                       d44,d45,d46,d55,d56,d66)

  use constants, only: R_UNIT_SPHERE,DEGREES_TO_RADIANS,ZERO,PI,GRAV
  use shared_parameters, only: R_PLANET,RHOAV

  implicit none

  double precision,intent(in) :: pro(47)
  integer,intent(in) :: npar1

  double precision,intent(out) :: rho
  double precision,intent(in) :: beta(14,34,37,73)

  double precision,intent(in) :: r,colat,lon
  double precision,intent(out) :: d11,d12,d13,d14,d15,d16,d22,d23,d24,d25,d26, &
                                  d33,d34,d35,d36,d44,d45,d46,d55,d56,d66

  ! local parameters
  double precision :: depth,tei,tet,ph,fi,x0,y0,pxy0
  double precision :: d1,d2,d3,d4,sd,thickness,dprof1,dprof2,eps,pc1,pc2,pc3,pc4, &
                   dpr1,dpr2,param,scale_GPa,scaleval
  double precision :: A,C,F,AL,AN,BC,BS,GC,GS,HC,HS,EC,ES,C1p,C1sv,C1sh,C3,S1p,S1sv,S1sh,S3
  double precision :: anispara(14,2,4),elpar(14)
  integer :: ndepth,idep,ipar,icolat,ilon,icz0,nx0,ny0,nz0, &
          ict0,ict1,icp0,icp1,icz1

  ndepth = npar1
  pxy0 = 5.d0
  x0 = 0.d0
  y0 = 0.d0

  nx0 = 37
  ny0 = 73
  nz0 = 34

  tet = colat
  ph = lon

! avoid edge effects
  if (tet == 0.0d0) tet = 0.000001d0
  if (tet == 180.d0) tet = 0.999999d0*tet
  if (ph == 0.0d0) ph = 0.000001d0
  if (ph == 360.d0) ph = 0.999999d0*ph

! dimensionalize
  depth = R_PLANET*(R_UNIT_SPHERE - r)/1000.d0
  if (depth <= pro(nz0) .or. depth >= pro(1)) call exit_MPI_without_rank('r out of range in build_cij')

  icolat = int(int(tet + pxy0)/pxy0)
  ilon = int(int(ph + pxy0)/pxy0)

  icz0 = 0
  do idep = 1,ndepth
    if (pro(idep) > depth) icz0 = icz0 + 1
  enddo

!
! Interpolation for depth between dep1(iz0) and dep2(iz1)
!
!    1 (ict0,icp0)      2 (ict0,icp1)
!    3 (ict1,icp0)      4 (ict1,icp1)
!

  ict0 = icolat
  ict1 = ict0 + 1
  icp0 = ilon
  icp1 = icp0 + 1
  icz1 = icz0 + 1

! check that parameters make sense
  if (ict0 < 1 .or. ict0 > nx0) call exit_MPI_without_rank('ict0 out of range')
  if (ict1 < 1 .or. ict1 > nx0) call exit_MPI_without_rank('ict1 out of range')
  if (icp0 < 1 .or. icp0 > ny0) call exit_MPI_without_rank('icp0 out of range')
  if (icp1 < 1 .or. icp1 > ny0) call exit_MPI_without_rank('icp1 out of range')
  if (icz0 < 1 .or. icz0 > nz0) call exit_MPI_without_rank('icz0 out of range')
  if (icz1 < 1 .or. icz1 > nz0) call exit_MPI_without_rank('icz1 out of range')

  do ipar = 1,14
    anispara(ipar,1,1) = beta(ipar,icz0,ict0,icp0)
    anispara(ipar,2,1) = beta(ipar,icz1,ict0,icp0)
    anispara(ipar,1,2) = beta(ipar,icz0,ict0,icp1)
    anispara(ipar,2,2) = beta(ipar,icz1,ict0,icp1)
    anispara(ipar,1,3) = beta(ipar,icz0,ict1,icp0)
    anispara(ipar,2,3) = beta(ipar,icz1,ict1,icp0)
    anispara(ipar,1,4) = beta(ipar,icz0,ict1,icp1)
    anispara(ipar,2,4) = beta(ipar,icz1,ict1,icp1)
  enddo

!
! calculation of distances between the selected point and grid points
!
  tei = pxy0*ict0 + x0 - pxy0
  fi = pxy0*icp0 + y0 - pxy0

!***  d1=de(tet,ph,tei,fi)

  d1 = dsqrt(((tei - tet)**2) + ((fi - ph)**2)*(dsin((tet + tei)*DEGREES_TO_RADIANS/2.)**2))

!***  d2=de(tet,ph,tei+pxy0,fi)

  d2 = dsqrt(((tei - tet + pxy0)**2) + ((fi - ph)**2)*(dsin((tet + tei + pxy0)*DEGREES_TO_RADIANS/2.)**2))

!***  d3=de(tet,ph,tei,fi+pxy0)

  d3 = dsqrt(((tei - tet)**2) + ((fi - ph + pxy0)**2)*(dsin((tet + tei)*DEGREES_TO_RADIANS/2.)**2))

!***  d4=de(tet,ph,tei+pxy0,fi+pxy0)

  d4 = dsqrt(((tei - tet + pxy0)**2) + ((fi - ph + pxy0)**2)*(dsin((tet + tei + pxy0)*DEGREES_TO_RADIANS/2.)**2))

  sd = d2*d3*d4 + d1*d2*d4 + d1*d3*d4 + d1*d2*d3
  thickness = pro(icz0) - pro(icz1)
  dprof1 = pro(icz0) - depth
  dprof2 = depth - pro(icz1)
  eps = 0.01

  do ipar = 1,14
     if (thickness < eps) then
      pc1 = anispara(ipar,1,1)
      pc2 = anispara(ipar,1,2)
      pc3 = anispara(ipar,1,3)
      pc4 = anispara(ipar,1,4)
     else
      dpr1 = dprof1/thickness
      dpr2 = dprof2/thickness
      pc1 = anispara(ipar,1,1)*dpr2+anispara(ipar,2,1)*dpr1
      pc2 = anispara(ipar,1,2)*dpr2+anispara(ipar,2,2)*dpr1
      pc3 = anispara(ipar,1,3)*dpr2+anispara(ipar,2,3)*dpr1
      pc4 = anispara(ipar,1,4)*dpr2+anispara(ipar,2,4)*dpr1
     endif
     param = pc1*d2*d3*d4 + pc2*d1*d3*d4 + pc3*d1*d2*d4 + pc4*d1*d2*d3
     param = param/sd
     elpar(ipar) = param
  enddo

  d11 = ZERO
  d12 = ZERO
  d13 = ZERO
  d14 = ZERO
  d15 = ZERO
  d16 = ZERO
  d22 = ZERO
  d23 = ZERO
  d24 = ZERO
  d25 = ZERO
  d26 = ZERO
  d33 = ZERO
  d34 = ZERO
  d35 = ZERO
  d36 = ZERO
  d44 = ZERO
  d45 = ZERO
  d46 = ZERO
  d55 = ZERO
  d56 = ZERO
  d66 = ZERO
!
!   create dij
!
  rho = elpar(1)
  A = elpar(2)
  C = elpar(3)
  F = elpar(4)
  AL = elpar(5)
  AN = elpar(6)
  BC = elpar(7)
  BS = elpar(8)
  GC = elpar(9)
  GS = elpar(10)
  HC = elpar(11)
  HS = elpar(12)
  EC = elpar(13)
  ES = elpar(14)
  C1p = 0.0d0
  S1p = 0.0d0
  C1sv = 0.0d0
  S1sv = 0.0d0
  C1sh = 0.0d0
  S1sh = 0.0d0
  C3 = 0.0d0
  S3 = 0.0d0

  d11 = A + EC + BC
  d12 = A - 2.d0*AN - EC
  d13 = F + HC
  d14 = S3 + 2.d0*S1sh + 2.d0*S1p
  d15 = 2.d0*C1p + C3
  d16 = -BS/2.d0 - ES
  d22 = A + EC - BC
  d23 = F - HC
  d24 = 2.d0*S1p - S3
  d25 = 2.d0*C1p - 2.d0*C1sh - C3
  d26 = -BS/2.d0 + ES
  d33 = C
  d34 = 2.d0*(S1p - S1sv)
  d35 = 2.d0*(C1p - C1sv)
  d36 = -HS
  d44 = AL - GC
  d45 = -GS
  d46 = C1sh - C3
  d55 = AL + GC
  d56 = S3 - S1sh
  d66 = AN - EC

! non-dimensionalize the elastic coefficients using
! the scale of GPa--[g/cm^3][(km/s)^2]
  scaleval = dsqrt(PI*GRAV*RHOAV)
  scale_GPa =(RHOAV/1000.d0)*((R_PLANET*scaleval/1000.d0)**2)

  d11 = d11/scale_GPa
  d12 = d12/scale_GPa
  d13 = d13/scale_GPa
  d14 = d14/scale_GPa
  d15 = d15/scale_GPa
  d16 = d16/scale_GPa
  d22 = d22/scale_GPa
  d23 = d23/scale_GPa
  d24 = d24/scale_GPa
  d25 = d25/scale_GPa
  d26 = d26/scale_GPa
  d33 = d33/scale_GPa
  d34 = d34/scale_GPa
  d35 = d35/scale_GPa
  d36 = d36/scale_GPa
  d44 = d44/scale_GPa
  d45 = d45/scale_GPa
  d46 = d46/scale_GPa
  d55 = d55/scale_GPa
  d56 = d56/scale_GPa
  d66 = d66/scale_GPa

! non-dimensionalize
  rho = rho*1000.d0/RHOAV

  end subroutine build_cij

!
!-------------------------------------------------------------------------------------------------
!

  subroutine read_aniso_mantle_model()

  use constants, only: IIN,DEGREES_TO_RADIANS
  use model_aniso_mantle_par

  implicit none

  ! local parameters
  integer :: nx,ny,np1,np2,ipar,ipa1,ipa,ilat,ilon,il,idep,nfin,nfi0,nf,nri
  double precision :: xinf,yinf,pxy,ppp,angle,A,A2L,AL,af
  double precision :: ra(47),pari(14,47)
  double precision,dimension(:,:,:,:),allocatable :: bet2 ! bet2(14,34,37,73)
  double precision :: alph(73,37),ph(73,37)
  integer :: ier
  character(len=*), parameter :: glob_prem3sm01 = 'DATA/Montagner_model/glob-prem3sm01'
  character(len=*), parameter :: globpreman3sm01 = 'DATA/Montagner_model/globpreman3sm01'

  ! dynamic allocation
  allocate(bet2(14,34,37,73),stat=ier)
  if (ier /= 0 ) stop 'Error allocating bet2 array'

  np1 = 1
  np2 = 34
  AMM_V_npar1 = (np2 - np1 + 1)

!
! read the models
!
! reference model: PREM or ACY400
!
  call lecmod(nri,pari,ra)

!
! glob-prem3sm01: model with rho,A,L,xi-1,1-phi,eta
!
  open(IIN,file=glob_prem3sm01,status='old',action='read',iostat=ier)
  if (ier /= 0 ) stop 'Error opening file DATA/Montagner_model/glob-prem3sm01'

!
! read tomographic model (equivalent T.I. model)
!
  ipa = 0
  nfi0 = 6
  nfin = 14
  do nf = 1,nfi0
    ipa = ipa + 1
    do idep = 1,AMM_V_npar1
      il = idep + np1 - 1
      read(IIN,"(2f4.0,2i3,f4.0)",end = 88) xinf,yinf,nx,ny,pxy

      ppp = 1.
      read(IIN,"(f5.0,f8.4)",end = 88) AMM_V_pro(idep),ppp

      if (nf == 1) pari(nf,il) = ppp
      if (nf == 2) pari(nf,il) = ppp
      if (nf == 3) pari(nf,il) = ppp
      if (nf == 4) ppp = pari(nf,il)
      if (nf == 5) ppp = pari(nf,il)
      do ilat = 1,nx
        read(IIN,"(17f7.2)",end = 88) (AMM_V_beta(ipa,idep,ilat,ilon),ilon = 1,ny)
!
! calculation of A,C,F,L,N
!
! bet2(1,...)  = rho,
! bet2(2,...)  = A,
! bet2(3,...)  = L,
! bet2(4,...)  = xi
! bet2(5,...)  = phi = C/A,
! bet2(6,...)  = eta = F/A-2L
! bet2(7,...)  = Bc,
! bet2(8,...)  = Bs,
! bet2(9,...)  = Gc,
! bet2(10,...) = Gs
! bet2(11,...) = Hc,
! bet2(12,...) = Hs,
! bet2(13,...) = Ec,
! bet2(14,...) = Es
!
        do ilon = 1,ny
          if (nf <= 3 .or. nf >= 6) then
            bet2(ipa,idep,ilat,ilon) = AMM_V_beta(ipa,idep,ilat,ilon)*0.01*ppp + ppp
          else
            if (nf == 4)bet2(ipa,idep,ilat,ilon) = AMM_V_beta(ipa,idep,ilat,ilon)*0.01 + 1.
            if (nf == 5)bet2(ipa,idep,ilat,ilon) = - AMM_V_beta(ipa,idep,ilat,ilon)*0.01 + 1.
          endif
        enddo

       enddo
     enddo
   enddo
88 close(IIN)

!
! read anisotropic azimuthal parameters
!

!
! beta(ipa,idep,ilat,ilon) are sorted in (amplitude, phase)
! normalized, in percents: 100 G/L
!
  open(unit=IIN,file=globpreman3sm01,status='old',action='read',iostat=ier)
  if (ier /= 0 ) stop 'Error opening file DATA/Montagner_model/globpreman3sm01'

  do nf = 7,nfin,2
    ipa = nf
    ipa1 = ipa + 1
    do idep = 1,AMM_V_npar1
      il = idep + np1 - 1
      read(IIN,"(2f4.0,2i3,f4.0)",end = 888) xinf,yinf,nx,ny,pxy
      read(IIN,"(f5.0,f8.4)",end = 888) AMM_V_pro(idep),ppp
      if (nf == 7) ppp = pari(2,il)
      if (nf == 9) ppp = pari(3,il)
      af = pari(6,il)*(pari(2,il) - 2.*pari(3,il))
      if (nf == 11) ppp = af
      if (nf == 13) ppp = (pari(4,il) + 1.)*pari(3,il)

      do ilat = 1,nx
        read(IIN,"(17f7.2)",end = 888) (alph(ilon,ilat),ilon = 1,ny)
      enddo

      do ilat = 1,nx
        read(IIN,"(17f7.2)",end = 888) (ph(ilon,ilat),ilon = 1,ny)
      enddo

      do ilat = 1,nx
        do ilon = 1,ny
          angle = 2.*DEGREES_TO_RADIANS*ph(ilon,ilat)
          AMM_V_beta(ipa,idep,ilat,ilon) = alph(ilon,ilat)*ppp*0.01d0
          AMM_V_beta(ipa1,idep,ilat,ilon) = ph(ilon,ilat)
          bet2(ipa,idep,ilat,ilon) = alph(ilon,ilat)*dcos(angle)*ppp*0.01d0
          bet2(ipa1,idep,ilat,ilon) = alph(ilon,ilat)*dsin(angle)*ppp*0.01d0
        enddo
      enddo

    enddo
  enddo

888 close(IIN)

  do idep = 1,AMM_V_npar1
    do ilat = 1,nx
      do ilon = 1,ny

! rho
        AMM_V_beta(1,idep,ilat,ilon) = bet2(1,idep,ilat,ilon)

! A
        AMM_V_beta(2,idep,ilat,ilon) = bet2(2,idep,ilat,ilon)
        A = bet2(2,idep,ilat,ilon)

!  C
        AMM_V_beta(3,idep,ilat,ilon) = bet2(5,idep,ilat,ilon)*A

!  F
        A2L = A - 2.*bet2(3,idep,ilat,ilon)
        AMM_V_beta(4,idep,ilat,ilon) = bet2(6,idep,ilat,ilon)*A2L

!  L
        AMM_V_beta(5,idep,ilat,ilon) = bet2(3,idep,ilat,ilon)
        AL = bet2(3,idep,ilat,ilon)

!  N
        AMM_V_beta(6,idep,ilat,ilon) = bet2(4,idep,ilat,ilon)*AL

!  azimuthal terms
        do ipar = 7,14
          AMM_V_beta(ipar,idep,ilat,ilon) = bet2(ipar,idep,ilat,ilon)
        enddo

      enddo
    enddo
  enddo

  deallocate(bet2)

  end subroutine read_aniso_mantle_model

!
!--------------------------------------------------------------------
!

  subroutine lecmod(nri,pari,ra)

  use constants, only: IIN

  implicit none

! read the reference Earth model: rho, Vph, Vsv, XI, PHI, ETA
! array par(i,nlayer)
! output: array pari(ipar, nlayer): rho, A, L, xi-1, phi-1, eta-1

  integer :: i,j,k,ip,idum1,idum2,idum3,nlayer,nout,neff, &
          nband,nri,minlay,moho,kiti
  double precision :: pari(14,47),qkappa(47),qshear(47),par(6,47)
  double precision :: epa(14,47),ra(47),dcori(47),ri(47)
  double precision :: corpar(21,47)
  double precision :: aa,an,al,af,ac,vpv,vph,vsv,vsh,rho,red,a2l
  character(len=80) :: nullval
  character(len=256), parameter :: Adrem119 = 'DATA/Montagner_model/Adrem119'

  nri = 47

  open(unit=IIN,file=Adrem119,status='old',action='read')
  read(IIN,*,end = 77) nlayer,minlay,moho,nout,neff,nband,kiti,nullval

  if (kiti == 0) read(IIN,"(20a4)",end = 77) idum1
  read(IIN,"(20a4)",end = 77) idum2
  read(IIN,"(20a4)",end = 77) idum3

  do i = 1,nlayer
    read(IIN,"(4x,f11.1,8d12.5)",end = 77) ra(i),(par(k,i),k = 1,6),qshear(i),qkappa(i)
  enddo

  do i = 1,nlayer
    ri(i) = 0.001*ra(i)
  enddo

  do i = 1,nlayer
    rho = par(1,i)
    pari(1,i) = rho
!   A : pari(2,i)
    pari(2,i) = rho*(par(2,i)**2)
    aa = pari(2,i)
!   L : pari(3,i)
    pari(3,i) = rho*(par(3,i)**2)
    al = pari(3,i)
!   Xi : pari(4,i)= (N-L)/L
    an = al*par(4,i)
    pari(4,i) = 0.
    pari(4,i) = par(4,i) - 1.
!   Phi : pari(5,i)=(a-c)/a
    pari(5,i) = - par(5,i) + 1.
    ac = par(5,i)*aa
!   f : pari(4,i)
    af = par(6,i)*(aa - 2.*al)
    pari(6,i) = par(6,i)
    do ip = 7,14
      pari(ip,i) = 0.
    enddo
    vsv = 0.
    vsh = 0.
    if (al < 0.0001 .or. an < 0.0001) goto 12
    vsv = dsqrt(al/rho)
    vsh = dsqrt(an/rho)
12    vpv = dsqrt(ac/rho)
    vph = dsqrt(aa/rho)
  enddo

  red = 1.
  do i = 1,nlayer
    read(IIN,"(15x,6e12.5,f11.1)",end = 77) (epa(j,i),j = 1,6),dcori(i)
    epa(7,i) = epa(2,i)
    epa(8,i) = epa(2,i)
    epa(9,i) = epa(3,i)
    epa(10,i) = epa(3,i)

    a2l = pari(2,i) - 2.*pari(3,i)
    epa(11,i) = epa(6,i)*a2l
    epa(12,i) = epa(6,i)*a2l
    epa(13,i) = epa(3,i)
    epa(14,i) = epa(3,i)

    do j = 1,14
      epa(j,i) = red*epa(j,i)
    enddo

    read(IIN,"(21f7.3)",end = 77) (corpar(j,i),j = 1,21)

  enddo

77 close(IIN)

  end subroutine lecmod


