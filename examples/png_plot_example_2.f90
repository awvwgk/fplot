program example
    use iso_fortran_env
    use fplot_core
    implicit none

    ! Local Variables & Parameters
    integer(int32), parameter :: npts = 1000
    real(real64), dimension(npts) :: x, y1, y2
    type(plot_2d) :: plt
    class(terminal), pointer :: term
    type(plot_data_2d) :: d1, d2
    class(plot_axis), pointer :: xAxis, yAxis
    type(legend), pointer :: leg

    ! Build a data set to plot
    x = linspace(0.0d0, 10.0d0, npts)
    y1 = sin(x) * cos(x)
    y2 = sqrt(x) * sin(x)

    call d1%define_data(x, y1)
    call d2%define_data(x, y2)

    ! Set up the plot
    call plt%initialize(GNUPLOT_TERMINAL_PNG) ! Save to file directly
    call plt%set_title("Example Plot")
    
    xAxis => plt%get_x_axis()
    call xAxis%set_title("X Axis")

    yAxis => plt%get_y_axis()
    call yAxis%set_title("Y Axis")

    ! Put the legend outside the axes, and remove it's border
    leg => plt%get_legend()
    call leg%set_is_visible(.true.)
    call leg%set_draw_inside_axes(.false.)
    call leg%set_draw_border(.false.)

    ! Set up line color and style properties to better distinguish each data set
    call d1%set_name("Data Set 1")
    call d1%set_line_color(CLR_BLUE)
    
    call d2%set_name("Data Set 2")
    call d2%set_line_color(CLR_GREEN)

    ! Add the data to the plot
    call plt%push(d1)
    call plt%push(d2)

    ! Define the file to which the plot should be saved
    term => plt%get_terminal()
    select type (term)
    class is (png_terminal)
        call term%set_filename("example_plot_legend_out.png")
    end select

    ! Draw the plot
    call plt%draw()
end program