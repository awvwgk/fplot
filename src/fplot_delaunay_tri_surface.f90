! fplot_delaunay_tri_surface.f90

submodule (fplot_core) fplot_delaunay_tri_surface
    use ieee_arithmetic
contains
! ------------------------------------------------------------------------------
    module subroutine dts_define_fcn(this, z, err)
        ! Arguments
        class(delaunay_tri_surface), intent(inout) :: this
        real(real64), intent(in), dimension(:) :: z
        class(errors), intent(inout), optional, target :: err

        ! Local Variables
        integer(int32) :: n, flag
        class(errors), pointer :: errmgr
        type(errors), target :: deferr
        character(len = 256) :: errmsg
        
        ! Initialization
        if (present(err)) then
            errmgr => err
        else
            errmgr => deferr
        end if
        n = this%get_point_count()

        ! Input Check
        if (n == 0) then
            call errmgr%report_error("dts_define_fcn", &
                "No x-y coordinates have been defined.", &
                PLOT_INVALID_OPERATION_ERROR)
            return
        end if
        if (size(z) /= n) then
            write (errmsg, 100) "The number of function values " // &
                "does not match the number of x-y points.  Expected to find ", &
                n, " function values, but found ", size(z), " instead."
            call errmgr%report_error("dts_define_fcn", trim(errmsg), &
                PLOT_ARRAY_SIZE_MISMATCH_ERROR)
            return
        end if

        ! Store the data
        if (allocated(this%m_z)) deallocate(this%m_z)
        allocate(this%m_z(n), stat = flag)
        if (flag /= 0) then
            call errmgr%report_error("dts_define_fcn", &
                "Insufficient memory available.", &
                PLOT_OUT_OF_MEMORY_ERROR)
            return
        end if
        this%m_z = z
        
100     format(A, I0, A, I0, A)
    end subroutine

! ------------------------------------------------------------------------------
    pure module function dts_get_z(this) result(rst)
        class(delaunay_tri_surface), intent(in) :: this
        real(real64), allocatable, dimension(:) :: rst
        if (allocated(this%m_z)) then
            rst = this%m_z
        else
            allocate(rst(0))
        end if
    end function

! ------------------------------------------------------------------------------
    ! Interpolation Routine - Barycentric Coordinate Approach
    ! https://www.iue.tuwien.ac.at/phd/nentchev/node25.html
    ! https://academic.csuohio.edu/duffy_s/CVE_512_11.pdf
    pure module function dts_interp_1(this, x, y) result(z)
        ! Arguments
        class(delaunay_tri_surface), intent(in) :: this
        real(real64), intent(in) :: x, y
        real(real64) :: z

        ! Local Variables
        integer(int32) :: i, n1, n2, n3
        real(real64) :: x1, x2, x3, y1, y2, y3, z1, z2, z3
        integer(int32), allocatable, dimension(:,:) :: indices
        real(real64), allocatable, dimension(:) :: xc, yc, zc

        ! Initialization
        z = ieee_value(z, ieee_quiet_nan)
        indices = this%get_indices()
        xc = this%get_points_x()
        yc = this%get_points_y()
        zc = this%get_points_z()

        ! Quick Return
        if (this%get_triangle_count() == 0 .or. &
            this%get_point_count() == 0 .or. &
            size(zc) == 0) return

        ! Locate the triangle to which the point (x, y) belongs.  If no triangle
        ! is found, simply return NaN
        i = this%find_triangle(x, y)
        if (i == -1) return

        ! Get the triangle vertices
        n1 = indices(i, 1)
        n2 = indices(i, 2)
        n3 = indices(i, 3)

        x1 = xc(n1)
        y1 = yc(n1)
        z1 = zc(n1)

        x2 = xc(n2)
        y2 = yc(n2)
        z2 = zc(n2)

        x3 = xc(n3)
        y3 = yc(n3)
        z3 = zc(n3)

        ! Perform the interpolation
        z = linear_interp(x1, y1, z1, x2, y2, z2, x3, y3, z3, x, y)
    end function

! --------------------
    pure module function dts_interp_2(this, x, y) result(z)
        ! Arguments
        class(delaunay_tri_surface), intent(in) :: this
        real(real64), intent(in), dimension(:) :: x, y
        real(real64), allocatable, dimension(:) :: z

        ! Local Variables
        integer(int32) :: i, j, n1, n2, n3, nxy
        real(real64) :: x1, x2, x3, y1, y2, y3, z1, z2, z3, nan
        integer(int32), allocatable, dimension(:,:) :: indices
        real(real64), allocatable, dimension(:) :: xc, yc, zc

        ! Initialization
        nxy = min(size(x), size(y))
        nan = ieee_value(nan, ieee_quiet_nan)
        allocate(z(nxy))
        z = nan
        indices = this%get_indices()
        xc = this%get_points_x()
        yc = this%get_points_y()
        zc = this%get_points_z()

        ! Quick Return
        if (this%get_triangle_count() == 0 .or. &
            this%get_point_count() == 0 .or. &
            size(zc) == 0) return

        ! Locate the triangle to which the point (x, y) belongs.  If no triangle
        ! is found, simply return NaN
        do i = 1, nxy
            ! Find the index of the triangle
            j = this%find_triangle(x(i), y(i))

            if (j == -1) cycle  ! Skip if we couldn't find a triangle

            ! Get the vertices
            n1 = indices(j, 1)
            n2 = indices(j, 2)
            n3 = indices(j, 3)

            x1 = xc(n1)
            y1 = yc(n1)
            z1 = zc(n1)

            x2 = xc(n2)
            y2 = yc(n2)
            z2 = zc(n2)

            x3 = xc(n3)
            y3 = yc(n3)
            z3 = zc(n3)

            ! Perform the interpolation
            z(i) = linear_interp(x1, y1, z1, x2, y2, z2, x3, y3, z3, x(i), y(i))
        end do
    end function

! ------------------------------------------------------------------------------
    ! Utilizes linear shape functions to interpolate on a triangle given its
    ! vertex locations, and the desired interpolation location.  Notice, the
    ! interpolation location is expected to lie within the triangle.  This is
    ! not checked.
    pure elemental function linear_interp(x1, y1, z1, x2, y2, z2, x3, &
            y3, z3, x, y) result(z)
        real(real64), intent(in) :: x1, y1, z1, x2, y2, z2, x3, y3, z3, x, y
        real(real64) :: a1, a2, a3, j, z

        j = (x2 - x1) * y3 + (x1 - x3) * y2 + (x3 - x2) * y1
        a1 = (x2 * y3 - x3 * y2 + (y2 - y3) * x + (x3 - x2) * y)
        a2 = (x3 * y1 - x1 * y3 + (y3 - y1) * x + (x1 - x3) * y)
        a3 = (x1 * y2 - x2 * y1 + (y1 - y2) * x + (x2 - x1) * y)
        z = (a1 * z1 + a2 * z2 + a3 * z3) / j
    end function

! ------------------------------------------------------------------------------
end submodule
