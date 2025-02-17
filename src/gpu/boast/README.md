# BOAST

This directory contains source files necessary to generate SPECFEM3D kernels in both CUDA and OpenCL flavor.


## Documentation:

see:

https://github.com/Nanosim-LIG/boast

http://www.rubydoc.info/github/Nanosim-LIG/boast/master


## Quick start:

1. Installation requires ruby:
  on Linux, e.g.:
  ```
  sudo apt-get install ruby ruby-dev
  ```

  on Mac, e.g. :
  ```
  fink install ruby
  ```
  or
  ```
  sudo port install ruby
  ```

2. install BOAST:
  ```
  gem install --user-install BOAST
  ```
  or
  ```
  sudo gem install BOAST
  ```

3. update BOAST:
  ```
  sudo gem update BOAST
  ```

###### BOAST help:

  /Library/Ruby/Gems/2.0.0/doc/BOAST-2.0.1/rdoc/index.html
  /Library/Ruby/Gems/2.0.0/gems/BOAST-2.0.1/README.md

###### Testing installation with interactive ruby:

```
> irb
irb(main):003:0> require 'BOAST'
irb(main):003:0> a = BOAST::Int "a"
irb(main):003:0> <ctrl-D>
```


## CUDA/OpenCL/HIP kernel generation:
Type:
```
cd ~/SPECFEM3D_GLOBE
make boast
```
or
```
cd SPECFEM3D_GLOBE/src/gpu/boast
ruby kernels.rb -o ../kernels.gen
```

Using ruby, you can regenerate the list of kernels. You might need to create an "output" directory in this folder during development.
so:
```
cd SPECFEM3D_GLOBE/src/gpu/boast/
mkdir output
ruby kernels.rb
```

will generate the kernels in the output/ directory.


## Testing

If non regression data are installed in specfem3d_globe/src/gpu/kernels.test/ then you can test the kernels by
```
ruby kernels.rb -c
```

This will use the non regression testing data to give you information about the behavior of the kernels (accuracy and performance).
If tests are not installed, it will just compile the kernels and check for compilation errors.

You might have to manually deactivate CUDA and HIP kernels test:
```
diff --git a/src/gpu/boast/kernels.rb b/src/gpu/boast/kernels.rb
index 4d2b31d..e4a678f 100644
--- a/src/gpu/boast/kernels.rb
+++ b/src/gpu/boast/kernels.rb
@@ -76,7 +76,7 @@ kernels = [
 :compute_iso_undoatt_kernel
 ]

-langs = [ :CUDA, :CL, :HIP]
+langs = [:CL]
 BOAST::set_default_real_size(4)
 BOAST::set_replace_constants(false)
 class Float
```

If you want Intel vectorization report you can execute BOAST in verbose mode:
```
VERBOSE=true ruby kernels.rb -c
```
or use different CL flags:
```
CLFLAGS=-cl-fast-relaxed-math ruby kernels.rb -c
```

That should be the default in SPECFEM3D (even if for now it seems the default is no flags for OpenCL, which gives a certain advantage to CUDA).

If you have a problem of platform selection or want to restrict the test to 1 kernel:
```
ruby kernels.rb -c -k crust_mantle_impl_kernel_forward -p INTEL
```

Once you want to test your kernels in SPECFEM3D then you can
```
ruby kernels.rb -c -o ../kernels.gen/
```

At this point you may need to reactivate CUDA support in order to have all the files correctly generated
(never tested without CUDA kernels being generated)
