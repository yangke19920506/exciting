!
! 11.02.16 (DIN) New version of the exciting subroutine to generate k-points
!
subroutine genppts (reducep, tfbz, ngridp, boxl, nppt, ipmap, &
&                   ivp, vpl, vpc, wppt)
    use modinput
    use modmain
#ifdef XS
    use modxs
#endif
#ifdef TETRA
      Use modtetra
#endif
    use modgw
    implicit none
    ! input
    logical, intent(in)  :: reducep
    logical, intent(in)  :: tfbz
    integer, intent(in)  :: ngridp(3)
    real(8), intent(in)  :: boxl(3,4)
    integer, intent(out) :: nppt
    integer, intent(out) :: ipmap(0:ngridp(1)-1,0:ngridp(2)-1,0:ngridp(3)-1)
    integer, intent(out) :: ivp(3,ngridp(1)*ngridp(2)*ngridp(3))
    real(8), intent(out) :: vpl(3,ngridp(1)*ngridp(2)*ngridp(3))
    real(8), intent(out) :: vpc(3,ngridp(1)*ngridp(2)*ngridp(3))
    real(8), intent(out) :: wppt(ngridp(1)*ngridp(2)*ngridp(3))
    ! local variables
    integer :: i1, i2, i3, ip, jp
    integer :: isym, lspl, iv (3)
    real(8) :: v1 (3), v2 (3), v3 (3)
    real(8) :: b (3, 3), s (3, 3), t1, t2

    ! tetrahedron library related variables
    integer(4) :: nsym
    integer(4), allocatable :: symmat(:,:,:)

#ifdef XS
    integer :: jsym, nsymcrys_, lsplsymc_(maxsymcrys), lsplsymct(maxsymcrys)
    ! use symmetries of little group of q
    if ((iqcu .ne. 0) .and. reducep) then
      if (nsymcrys .ne. nsymcrysq(iqcu)) then
        write(*,'(a)') 'Info(genppts): Using associated(input%structure%symmetries) of the (little/small) group of q only'
      end if
      ! save global variables
      nsymcrys_ = nsymcrys
      lsplsymc_(:) = lsplsymc(:)
      ! map to point group elements
      lsplsymct(:) = 0
      jsym = 0
      do isym = 1, nsymcrysq(iqcu)
        jsym = jsym+1
        lsplsymct(jsym) = lsplsymc(scqmap(isym, iqcu))
      end do
      ! update global variables
      nsymcrys = nsymcrysq(iqcu)
      lsplsymc (:) = lsplsymct(:)
    end if
    ! now we are working with the point group symmetries of the small group of q
#endif

    if ((ngridp(1) <= 0) .or. &
    &   (ngridp(2) <= 0) .or. &
    &   (ngridp(3) <= 0)) then
      write(*,*)
      write(*,'("Error(genppts): invalid ngridp : ", 3I8)') ngridp
      write(*,*)
      stop
    end if

    nppt = ngridp(1)*ngridp(2)*ngridp(3)

    if (input%groundstate%stypenumber < 0) then
      !--------------------
      ! Tetrahedron method
      !--------------------
      nsym = 1
      if (reducep) nsym = nsymcrys

      if(allocated(symmat))deallocate(symmat)
      allocate(symmat(3,3,nsym))
      do isym = 1, nsym
        lspl = lsplsymc(isym)
        ! transpose of rotation for use with the library
        do i1 = 1, 3
          do i2 = 1, 3
            symmat(i1,i2,isym) = symlat(i2,i1,lspl)
          end do
        end do
      end do
             
      ! suppress debug output in tetrahedron integration library (0)
      call tetrasetdbglv(0)

      ! k-offset treatment
      call factorize(3,boxl(:,1)*ngridp(:),ikloff,dkloff)

      if (allocated(indkp)) deallocate(indkp)
      allocate(indkp(nppt))
      if (allocated(iwkp)) deallocate(iwkp)
      allocate(iwkp(nppt))
        
      ntet = 6*nppt
      if (allocated(wtet)) deallocate(wtet)
      allocate(wtet(ntet))
      if (allocated(tnodes)) deallocate(tnodes)
      allocate(tnodes(4,ntet))

      ! LibBZInt library call
      call kgen(bvec, nsym, symmat, ngridp, ikloff, dkloff, &
      &         nppt, ivp, dvk, indkp, iwkp, ntet, tnodes, wtet, tvol, mnd)

      ip = 0
      do i1 = 0, ngridp(1)-1
      do i2 = 0, ngridp(2)-1
      do i3 = 0, ngridp(3)-1
        ip = ip+1
        ipmap(i1,i2,i3) = indkp(ip)
      end do
      end do
      end do
        
      do ip = 1, nppt
        vpl(:,ip) = dble(ivp(:,ip))/dble(dvk)
        call r3mv(bvec,vpl(:,ip),vpc(:,ip))
        ! to match the exciting definition (integer devision)
        ivp(:,ip) = ivp(:,ip)*ngridp(:)/dvk
        wppt(ip) = dble(iwkp(ip))/dble(ngridp(1)*ngridp(2)*ngridp(3))
      end do ! ik

      deallocate(symmat)

    else

      ! box vector matrix
      b(:,1) = boxl(:,2)-boxl(:,1)
      b(:,2) = boxl(:,3)-boxl(:,1)
      b(:,3) = boxl(:,4)-boxl(:,1)
      t1 = 1.d0 / dble(ngridp(1)*ngridp(2)*ngridp(3))

      ! WARNING: Order of loops !
      ip = 0
      do i1 = 0, ngridp(1)-1
        v1(1) = dble(i1) / dble(ngridp(1))
        do i2 = 0, ngridp(2)-1
          v1(2) = dble(i2) / dble(ngridp(2))
            do i3 = 0, ngridp(3)-1
            v1(3) = dble(i3) / dble(ngridp(3))
            call r3mv(b, v1, v2)
            v2(:) = v2(:)+boxl(:,1)
            if (reducep) Then
              call r3frac(input%structure%epslat, v2, iv)
              ! determine if this point is equivalent to one already in the set
              do isym = 1, nsymcrys
                lspl = lsplsymc(isym)
                s(:, :) = dble(symlat(:,:,lspl))
                call r3mtv(s, v2, v3)
                call r3frac(input%structure%epslat, v3, iv)
                do jp = 1, ip
                  t2 = abs(vpl(1,jp)-v3(1)) + &
                  &    abs(vpl(2,jp)-v3(2)) + &
                  &    abs(vpl(3,jp)-v3(3))
                  if (t2 < input%structure%epslat) then
                    ! equivalent k-point found so add to current weight
                    ipmap(i1, i2, i3) = jp
                    wppt(jp) = wppt(jp) + t1
                    goto 10
                  end if
                end do
              end do
            end if ! reducep
            ! add new point to set
            ip = ip + 1
            ipmap(i1,i2,i3) = ip
            ivp(1,ip) = i1
            ivp(2,ip) = i2
            ivp(3,ip) = i3
            vpl(:,ip) = v2(:)
            wppt(ip)  = t1
10          continue
          end do
        end do
      end do
      nppt = ip

      write(*,*) 'ikloff=', ikloff
      write(*,*) 'dkloff=', dkloff
      write(*,*) 'dvk=', dvk
      write(*,*) 'ivp='
      do ip = 1, nppt
        write(*,*) ip, "--", ivp(:,ip)
      end do

    end if ! tetra vs default

    do ip = 1, nppt
      ! map vpl to the first Brillouin zone if required
      if (tfbz) call vecfbz(input%structure%epslat, bvec, vpl(:,ip), iv)
      ! determine the Cartesian coordinates of the p-points
      call r3mv(bvec, vpl(:,ip), vpc(:,ip))
    end do

#ifdef XS
    if ((iqcu .ne. 0) .and. reducep) then
      ! restore global variables
      nsymcrys = nsymcrys_
      lsplsymc(:) = lsplsymc_(:)
    end if
#endif

    Return
End Subroutine
