#!/Users/duda/ramdisk/dash-master/bin/dash

filename=c_loc.F90

char_copyin_code()
{
    cat >> ${filename} << EOF
!
!       Here is example code for copying whatever ${io}
!
EOF
}


################################################################################
#
# gen_getput_var
#
# Generate a function body for a specific "SMIOLf_put/get_var" function
# Required variables:
#  d = 0, 1, 2, 3
#  io = put, get
#  colon_list = ":,:,:"
#  dim_list = "d1,d1,d3"
#  type = real32, real64
#  kind = c_float, c_double
#  base_type = real, integer
#  size_args = "size(buf,dim=1), size(buf,dim=2)"
#
################################################################################
gen_getput_var()
{
    #
    # For non-scalars, build, e.g., " dimension(:,:,:),"
    #
    if [ $d -ge 1 ]; then
        dim=" dimension(${colon_list}),"
        c_loc_invocation="c_buf = c_loc_assumed_shape_${d}d_${type}(buf${size_args})"
    else
        dim=""
        c_loc_invocation="c_buf = c_loc(buf)"
    fi

    #
    # Character variables need special copying code...
    #
    if [ "${kind}" = "c_char" ]; then
        if [ "${io}" = "put" ]; then
            char_copyin="! Copy to a local c_char array here"
            char_copyout=""
        else
            char_copyin=""
            char_copyout="! Copy to Fortran string here"
        fi
        dummy_buf_decl="${base_type},${dim} pointer :: buf"
    else
        char_copyin=""
        char_copyout=""
        dummy_buf_decl="${base_type}(kind=${kind}),${dim} pointer :: buf"
    fi

    cat >> ${filename} << EOF
    function SMIOLf_${io}_var_${d}d_${type}(file, varname, decomp, buf) result(ierr)

        use iso_c_binding, only : ${kind}, c_char, c_loc, c_ptr, c_null_ptr, c_null_char

        implicit none

        ! Arguments
        type(SMIOLf_file), target :: file
        character(len=*), intent(in) :: varname
        type(SMIOLf_decomp), pointer :: decomp
        ${dummy_buf_decl}

        ! Return status code
        integer :: ierr

        ! Local variables
        integer :: i
        character(kind=c_char), dimension(:), pointer :: c_varname
        type (c_ptr) :: c_file
        type (c_ptr) :: c_decomp
        type (c_ptr) :: c_buf

        interface
            function SMIOL_${io}_var(file, varname, decomp, buf) result(ierr) bind(C, name='SMIOL_${io}_var')
                 use iso_c_binding, only : c_ptr, c_char, c_int
                 type (c_ptr), value :: file
                 character (kind=c_char), dimension(*) :: varname
                 type (c_ptr), value :: decomp
                 type (c_ptr), value :: buf
                 integer (kind=c_int) :: ierr
            end function
        end interface


        !
        ! file is a target, so no need to check that it is associated
        !
        c_file = c_loc(file)

        !
        ! decomp may be an unassociated pointer if the corresponding field is
        ! not decomposed
        !
        if (associated(decomp)) then
            c_decomp = c_loc(decomp)
        else
            c_decomp = c_null_ptr
        end if

        !
        ! Convert variable name string
        !
        allocate(c_varname(len_trim(varname) + 1))
        do i=1,len_trim(varname)
            c_varname(i) = varname(i:i)
        end do
        c_varname(i) = c_null_char

        !
        ! buf may be an unassociated pointer if the calling task does not read
        ! or write any elements of the field
        !
        if (associated(buf)) then
        ${c_loc_invocation}
        else
            c_buf = c_null_ptr
        end if

        ${char_copyin}
        ierr = SMIOL_${io}_var(c_file, c_varname, c_decomp, c_buf)
        ${char_copyout}

        deallocate(c_varname)

    end function SMIOLf_${io}_var_${d}d_${type}


EOF
}


################################################################################
#
# gen_c_loc
#
# Generate a function body for a specific "c_loc_assumed_shape" function
# Required variables:
#  d = 1, 2, 3
#  dim_args = , d1, d1, d3
#  dim_list = d1,d1,d3
#  type = real32, real64
#  kind = c_float, c_double
#  base_type = real, integer
#
################################################################################
gen_c_loc()
{
    #
    # Build, e.g., " dimension(d1,d2,d3),"
    #
    dim=" dimension(${dim_list}),"

    #
    # Build list of dimension argument declarations
    #
    d_decl="integer, intent(in) :: d1"
    i=2
    while [ $i -le $d ]; do
        d_decl="${d_decl}, d$i"
        i=$(($i+1))
    done

    cat >> ${filename} << EOF
    function c_loc_assumed_shape_${d}d_${type}(a${dim_args}) result(a_ptr)

        use iso_c_binding, only : c_ptr, c_loc, ${kind}

        implicit none

        ${d_decl}
        ${base_type}(kind=${kind}),${dim} target, intent(in) :: a
        type (c_ptr) :: a_ptr

        a_ptr = c_loc(a)

    end function c_loc_assumed_shape_${d}d_${type}


EOF
}


################################################################################
#
# gen_put_get.sh
#
################################################################################
printf "" > ${filename}

#
# For each type, handle each dimensionality
#
for d in 0 1 2 3 4 5; do

    #
    # Build list of dimension formal arguments, e.g. ", d1, d2, d3"
    #
    dim_args=''
    i=1
    while [ $i -le $d ]; do
       dim_args="${dim_args}, d$i"
       i=$(($i+1))
    done

    #
    # Build explicit shape list, e.g., "d1,d2,d3"
    #
    dim_list=''
    i=1
    while [ $i -le $d ]; do
        dim_list="${dim_list}d$i"
        if [ $i -lt $d ]; then
            dim_list="${dim_list},"
        fi
        i=$(($i+1))
    done

    #
    # Build assumed shape list, e.g., ":,:,:"
    #
    colon_list=''
    i=1
    while [ $i -le $d ]; do
        colon_list="${colon_list}:"
        if [ $i -lt $d ]; then
            colon_list="${colon_list},"
        fi
        i=$(($i+1))
    done

    #
    # Build array size actual arguments , e.g., "size(buf,dim=1), size(buf,dim=2)"
    #
    size_args=''
    i=1
    while [ $i -le $d ]; do
        size_args="${size_args},size(buf,dim=$i)"
        i=$(($i+1))
    done

    #
    # Create functions for each type
    #
    for type in char real32 real64 int32; do

        # Only up to 0-d char interfaces
        if [ "${type}" = "char" ] && [ $d -gt 0 ]; then
            continue
        fi

        # Only up to 3-d int32 interfaces
        if [ "${type}" = "int32" ] && [ $d -gt 3 ]; then
            continue
        fi

        if [ "$type" = "real32" ]; then
            kind="c_float"
            base_type="real"
        elif [ "$type" = "real64" ]; then
            kind="c_double"
            base_type="real"
        elif [ "$type" = "int32" ]; then
            kind="c_int"
            base_type="integer"
        elif [ "$type" = "char" ]; then
            kind="c_char"
            base_type="character(len=*)"
        fi

        if [ $d -ge 1 ]; then
            gen_c_loc
        fi

        for io in get put; do
            gen_getput_var
        done

    done

done
