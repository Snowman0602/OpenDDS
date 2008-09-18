package IDL2JNIHelper;

# ************************************************************
# Description   : Assist in determining the output from idl2jni.
#                 Much of the file processing code was lifted
#                 directly from the IDL compiler for opalORB.
# Author        : Chad Elliott
# Create Date   : 7/1/2008
# ************************************************************

# ************************************************************
# Pragmas
# ************************************************************

use strict;
use FileHandle;

use CommandHelper;
our @ISA = qw(CommandHelper);

# ************************************************************
# Data Section
# ************************************************************

my $helper = 'Helper';
my $holder = 'Holder';
my @local  = ('LocalBase', 'TAOPeer');
my $ops    = 'Operations';
my $stub   = 'Stub';
my $ext    = '.java';
my $tsreg  = 'TypeSupport\.idl';
my %types  = ('const'           => 0x01,
              'enum'            => 0x07,
              'native'          => 0x06,
              'struct'          => 0x07,
              'union'           => 0x07,
              'interface'       => 0x1f,
              'local interface' => 0x2f,
              'typedef'         => 0x06,
              'simple typedef'  => 0x04,
             );

my %idl_keywords = ('abstract' => 1,
                    'any' => 1,
                    'attribute' => 1,
                    'boolean' => 1,
                    'case' => 1,
                    'char' => 1,
                    'component' => 1,
                    'const' => 3,
                    'context' => 1,
                    'custom' => 1,
                    'default' => 1,
                    'double' => 1,
                    'emits' => 1,
                    'enum' => 2,
                    'eventtype' => 1,
                    'exception' => 2,
                    'factory' => 1,
                    'FALSE' => 1,
                    'finder' => 1,
                    'fixed' => 1,
                    'float' => 1,
                    'getraises' => 1,
                    'home' => 1,
                    'import' => 1,
                    'in' => 1,
                    'inout' => 1,
                    'interface' => 2,
                    'local' => 4,
                    'long' => 1,
                    'manages' => 1,
                    'module' => 2,
                    'multiple' => 1,
                    'native' => 3,
                    'Object' => 1,
                    'octet' => 1,
                    'oneway' => 1,
                    'out' => 1,
                    'primarykey' => 1,
                    'private' => 1,
                    'provides' => 1,
                    'public' => 1,
                    'publishes' => 1,
                    'raises' => 1,
                    'readonly' => 1,
                    'sequence' => 1,
                    'setraises' => 1,
                    'short' => 1,
                    'string' => 1,
                    'struct' => 2,
                    'supports' => 1,
                    'switch' => 1,
                    'TRUE' => 1,
                    'truncatable' => 1,
                    'typedef' => 3,
                    'typeid' => 1,
                    'typeprefix' => 1,
                    'union' => 2,
                    'unsigned' => 1,
                    'uses' => 1,
                    'ValueBase' => 1,
                    'valuetype' => 2,
                    'void' => 1,
                    'wchar' => 1,
                    'wstring' => 1,
                   );

# ************************************************************
# Public Interface Section
# ************************************************************

sub get_output {
  my($self, $file, $flags) = @_;

  ## Set up the macros and include paths supplied in the command flags
  my %macros;
  my %mparams;
  my @include;
  if (defined $flags) {
    foreach my $arg (split(/\s+/, $flags)) {
      if ($arg =~ /^\-D(\w+)(?:=(.+))?/) {
        $macros{$1} = $2 || 1;
      }
      elsif ($arg =~ /^\-I(.+)/) {
        push(@include, $1);
      }
    }
  }

  ## Parse the IDL file and get back the types and names
  my $data = $self->cached_parse($file, \@include, \%macros, \%mparams);

  ## Get the file names based on the type and name of each entry
  my @filenames;
  foreach my $ent (@$data) {
    push(@filenames, $self->get_filenames(@$ent));
  }

  ## Return the file name list
  return \@filenames;
}

sub get_outputexts {
  return ['\\' . $ext];
}

sub get_tied {
  my($self, $file, $files) = @_;
  my $tied = [];

  my $ts = $tsreg;
  $ts =~ s/\\//g;
  $file =~ s/\.idl$//;

  foreach my $f (@$files) {
    if ($f eq "$file$ts") {
      push(@$tied, $f);
      last;
    }
  }

  return $tied, 'java_files';
}

# ************************************************************
# File Processing Subroutine Section
# ************************************************************

sub get_filenames {
  my($self, $type, $dir, $name) = @_;
  my $bits = $types{$type};
  my @filenames;

  ## Get the file names based on the type of data structure
  push(@filenames, $dir . $name . $ext)                if ($bits & 0x01);
  push(@filenames, $dir . $name . $holder. $ext)       if ($bits & 0x02);
  push(@filenames, $dir . $name . $helper. $ext)       if ($bits & 0x04);
  push(@filenames, $dir . $name . $ops . $ext)         if ($bits & 0x08);
  push(@filenames, $dir . '_' . $name . $stub . $ext)  if ($bits & 0x10);
  if ($bits & 0x20) {
    foreach my $local_suffix (@local) {
      push(@filenames, $dir . '_' . $name . $local_suffix . $ext);
    }
  }
  return @filenames;
}

sub get_scope {
  my($self, $state) = @_;
  my $scope = '';

  ## Go through each entry and build up the scope using '/' as the
  ## separator.
  foreach my $entry (@$state) {
    if ($$entry[0] eq 'module') {
      $scope .= $$entry[1] . '/';
    }
    else {
      ## If it's not a module, then the word 'Package' will be part of
      ## the directory structure.
      $scope .= $$entry[1] . 'Package/';
    }
  }

  return $scope;
}

sub cached_parse {
  my($self, $file, $includes, $macros, $mparams) = @_;

  ## Convert all $(...) to the value of the current environment variable.
  ## It's not 100%, but it's the best we can do.
  while($file =~ /\$\(([^\)]+)\)/) {
    my $val = $ENV{$1} || '';
    $file =~ s/\$\([^\)]+\)/$val/;
  }

  ## If we have already processed this file, we will just delete the
  ## stored data and return it.
  return delete $self->{'files'}->{$file} if (defined $self->{'files'}->{$file});

  ## If the file is a DDS type support idl file, we will remove the
  ## TypeSupport portion and process the file from which it was created.
  ## In the process, we will store up the "contents" of the type support
  ## idl file for use below.
  ##
  ## If the type support file had previously been preprocessed, we will
  ## just parse the preprocessed string and continue on as usual.
  my $actual = $file;
  my $ts = defined $self->{'strs'}->{$actual} ||
           ($actual =~ /$tsreg$/ && -r $actual) ?
                   undef : ($actual =~ s/$tsreg$/.idl/);
  my($data, $ts_str) = $self->parse($actual, $includes, $macros, $mparams);

  if ($ts) {
    ## The file passed into this method was the type support file.  Store
    ## the data processed from the non-type support file and parse the
    ## string that was obtained during the original parsing and return
    ## that data.
    $self->{'files'}->{$actual} = $data;
    ($data, $ts_str) = $self->parse($file, $includes,
                                    $macros, $mparams, $ts_str);
  }
  elsif ($ts_str) {
    ## The file passed in was not a type support, but contained #pragma's
    ## that indicate a type support file will be generated, we will store
    ## that text for later use (in preprocess).
    my $key = $file;
    $key =~ s/\.idl$/$tsreg/;
    $key =~ s/\\//g;
    $self->{'strs'}->{$key} = $ts_str;
  }

  return $data;
}

sub parse {
  my($self, $file, $includes, $macros, $mparams, $str) = @_;

  ## Preprocess the file into one huge string
  my $ts_str;
  ($str, $ts_str) = $self->preprocess($file, $includes,
                                      $macros, $mparams) if (!defined $str);

  ## Keep track of const's and typedef's with these variables
  my $single;
  my $stype;
  my $simple;
  my $seq = 0;

  ## Keep track of whether or not an interface is local
  my $local;

  ## Keep track of forward declartions.
  my $forward;

  ## Tokenize the string and save the data
  my @data;
  my @state;
  while(length($str) != 0) {
    ## Remove starting white-space
    $str =~ s/^\s+//;

    ## Now check the start of the string for a particular type
    if ($str =~ s/^(("([^\\"]*|\\[abfnrtvx\\\?'"]|\\[0-7]{1,3})*"\s*)+)//) {
      ## String literal
    }
    elsif ($str =~ s/^((L"([^\\"]*|\\[abfnrtvx\\\?'"]|\\[0-7]{1,3}|\\u[0-9a-fA-F]{1,4})*"\s*)+)//) {
      ## Wstring literal
    }
    elsif ($str =~ s/^L'(.|\\.|\\[0-7]{1,3}|\\x[a-f\d]{1,2}|\\u[a-f\d]{1,4})'//i) {
      ## Wchar literal
    }
    elsif ($str =~ s/^([a-z_][\w]*)//i) {
      my $name    = $1;
      my $keyword = $idl_keywords{$name};
      if ($keyword) {
        if ($keyword == 2) {
          ## It's a keyword that requires an opening '{'
          push(@state, [$name]);
          $forward = 1;
        }
        elsif ($keyword == 3) {
          ## This is either a const, a typedef, or a native.  If it's a
          ## native, then we do not need to wait for an additional type
          ## ($stype).
          $single = $name;
          $stype = 1 if ($name ne 'native');
          $simple = 1;
        }
        elsif ($keyword == 4) {
          ## The interface will be local
          $local = 1;
        }
        else {
          ## This is not a keyword that we care about.  We need to
          ## reset this flag so that we know that in a typedef, we have
          ## found the original type part.
          $stype = undef;
        }
      }
      else {
        ## We're not going to do any checks on the word here.  If it is
        ## invalid (i.e., starts with more than one underscore, differs
        ## only in case from keyword, etc.) we'll let the real tool catch
        ## it.
        if (defined $single) {
          ## If we are not inside the type part of the sequence
          if ($seq == 0) {
            ## If we are waiting for the original type in the typedef,
            ## then we need to skip this word.
            if ($stype) {
              ## However, we only want to reset $stype if this is the end
              ## of the type.  If there is a fully qualified scoped name,
              ## it will be separated into parts at the double colon.
              $stype = undef if ($str =~ /^\s+/);
            }
            else {
              ## Otherwise, we will save the const or typedef in the data
              ## section.

              ## If this is a simple typedef, we need to prefix it with
              ## the word 'simple' so that we know which files will be
              ## generated from it.
              $single = 'simple ' . $single
                     if ($simple && $single eq 'typedef' && $str !~ /^\s*\[/);

              ## Get the scope and put the entry in the data array
              my $scope = $self->get_scope(\@state);
              push(@data, [$single, $scope, $name]);

              ## Reset this so that we don't continue adding entries
              $single = undef;
            }
          }
        }
        elsif ($#state >= 0 && !defined $state[$#state]->[1]) {
          $state[$#state]->[1] = $name;
        }
      }
    }
    elsif ($str =~ s/^([\-+]?(\d+(\.(\d+)?)?|\.\d+)d)//i) {
      ## Fixed literal
    }
    elsif ($str =~ s/^(-?(((\d+\.\d*)|(\.\d+))(e[+-]?\d+)?[lf]?|\d+e[+-]?\d+[lf]?))//i) {
      ## Floating point literal
    }
    elsif ($str =~ s/^(\-(0x[a-f0-9]+|0[0-7]*|\d+))//i) {
      ## Integer literal
    }
    elsif ($str =~ s/^((0x[a-f0-9]+|0[0-7]*|\d+))//i) {
      ## Unsigned integer literal
    }
    elsif ($str =~ s/^'(.|\\.|\\[0-7]{1,3}|\\x[a-f\d]{1,2})'//) {
      ## Character literal
    }
    elsif ($str =~ s/^(<<|>>|::|=)//) {
      ## Special symbols
    }
    elsif (length($str) != 0) {
      ## Generic character
      my $c = substr($str, 0, 1);
      substr($str, 0, 1) = '';

      ## We have not determined if this is a forward declaration yet.  If
      ## we see a semi-colon before an opening curly brace, then it's a
      ## forward declaration and we need to drop it.
      if ($forward) {
        if ($c eq '{') {
          $forward = undef;
        }
        elsif ($c eq ';') {
          pop(@state);
          $forward = undef;
        }
      }

      ## We've found a closing brace
      if ($c eq '}') {
        ## See if the start of the scope is something that we support
        my $entry = pop(@state);
        if (defined $$entry[0] && $types{$$entry[0]}) {
          ## If the local flag is set, then this must be a local interface
          if ($local) {
            $$entry[0] = 'local ' . $$entry[0];
            $local = undef;
          }

          my $scope = $self->get_scope(\@state);
          splice(@$entry, 1, 0, $scope);

          ## Save the entry in the data array
          push(@data, $entry);
        }
      }
      elsif ($c eq '<') {
        ## Keep track of the sequence type opening
        $seq++;

        ## A sequence typedef is not simple
        $simple = undef;
      }
      elsif ($c eq '>') {
        ## Keep track of the sequence type closing
        $seq--;
      }
    }
  }

  return \@data, $ts_str;
}

# ************************************************************
# Preprocessor Subroutine Section
# ************************************************************

sub preprocess {
  my($self, $file, $includes, $macros, $mparams, $included) = @_;
  my $fh = new FileHandle();
  my $contents = '';
  my $skip = [];
  my $ts_str = '';

  if (open($fh, $file)) {
    my $line;
    my $saved = '';
    my $in_comment;
    while(<$fh>) {
      ## Get the starting and ending position of a string
      my $qs = index($_, '"');
      my $qe = rindex($_, '"', length($_) - 1);

      ## Look for the starting point of a C++ comment
      my $cs = index($_, '//');
      if ($cs < $qs || $cs > $qe) {
        ## If it's not inside of a string, remove it
        $_ =~ s/\/\/.*//;
      }

      ## Look for the starting point of a C-style comment
      $cs = index($_, '/*');
      if ($cs < $qs || $cs > $qe) {
        ## Remove the one line c comment if it's not inside of a string
        $_ =~ s/\/\*.*\*\///;
      }

      ## Check for multi-lined c comments
      if (($cs < $qs || $cs > $qe) && $_ =~ s/\/\*.*//) {
        $in_comment = 1;
      }
      elsif ($in_comment) {
        if ($_ =~ s/.*\*\///) {
          ## We've found the end of the C-style comment
          $in_comment = undef;
        }
        else {
          ## We're still in the C-style comment, so just empty it out.
          $_ = '';
        }
      }

      if (/(.*)\\\s*$/) {
        ## If this is a concatenation line, save it for later
        $saved .= $1;
        $saved =~ s/\s+$/ /;
      }
      else {
        $line = $saved . $_;
        $saved = '';

        ## Remove trailing white space
        $line =~ s/\s+$//;

        ## Check for a preprocessor directive.  We support if/ifdef/ifendif
        ## and various others.
        if ($line =~ s/^\s*#\s*//) {
          my $pline = $line;
          $line = '';
          if ($pline =~ /^if\s+(.*)/) {
            ## If we're currently skipping text due to some other #if,
            ## add another skip so that when we find the matching #endif,
            ## we don't stop skipping text.
            if ($$skip[scalar(@$skip) - 1]) {
              push(@$skip, 1);
            }
            else {
              ## Send the #if off to be evaluated
              push(@$skip, !$self->evaluate_if($macros, $1));
            }
          }
          elsif ($pline =~ /^ifdef\s+(.*)/) {
            ## If we're currently skipping text due to some other #if,
            ## add another skip so that when we find the matching #endif,
            ## we don't stop skipping text.
            my $expr = $1;
            if ($$skip[scalar(@$skip) - 1]) {
              push(@$skip, 1);
            }
            else {
              ## Check for the macro definition.  If it's defined, we're
              ## not going to skip the next set of text.
              if (defined $macros->{$expr}) {
                push(@$skip, 0);
              }
              else {
                push(@$skip, 1);
              }
            }
          }
          elsif ($pline =~ /^ifndef\s+(.*)/) {
            ## If we're currently skipping text due to some other #if,
            ## add another skip so that when we find the matching #endif,
            ## we don't stop skipping text.
            my $expr = $1;
            if ($$skip[scalar(@$skip) - 1]) {
              push(@$skip, 1);
            }
            else {
              ## Check for the macro definition.  If it's defined, we're
              ## are going to skip the next set of text.
              if (defined $macros->{$expr}) {
                push(@$skip, 1);
              }
              else {
                push(@$skip, 0);
              }
            }
          }
          elsif ($pline =~ /^else$/) {
            ## Make sure we have a corresponding #if
            if (defined $$skip[0]) {
              ## We know that there is at least one element in the $skip
              ## array.  But, if there is more than one element, we have to
              ## check the #if in front of this one in the stack to see if
              ## we can stop skipping text.  If the #if in front of this
              ## one (or even farther in front) is causing skipping, we
              ## need to continue skipping even after processing this #else.
              if (scalar(@$skip) == 1 || !$$skip[scalar(@$skip) - 2]) {
                $$skip[scalar(@$skip) - 1] ^= 1;
              }
            }
            else {
              ## #else without a #if
              last;
            }
          }
          elsif ($pline =~ /^endif$/) {
            if (defined $$skip[0]) {
              pop(@$skip);
            }
            else {
              ## #endif without a #if
              last;
            }
          }
          elsif (!$$skip[scalar(@$skip) - 1]) {
            ## If we're not skipping text, see if the preprocessor
            ## directive was an include.
            if ($pline =~ /^include\s+(["<])(.*)([>"])$/) {
              my $s     = $1;
              my $file  = $2;
              my $e     = $3;

              ## Make sure that we have matching include file delimiters
              if (!(($s eq '<' && $e eq '>') || $s eq $e)) {
                ## Unmatched character
              }
              else {
                $self->include_file($file, $includes, $macros, $mparams);
              }
            }
            elsif ($pline =~ /^define\s+(([a-z_]\w+)(\(([^\)]+)\))?)(\s+(.*))?$/i) {
              my $name   = $2;
              my $params = $4;
              my $value  = $6 || 1;

              ## Define the macro and save the parameters (if there were
              ## any).  We will use it later on in the replace_macros()
              ## method.
              $macros->{$name} = $value;
              if (defined $params) {
                my @params = split(/\s*,\s*/, $params);
                $mparams->{$name} = \@params;
              }
            }
            elsif ($pline =~ /^pragma\s+(.*)/) {
              my $arg = $1;
              if ($arg =~ /^DCPS_DATA_TYPE\s+"(.*)"$/) {
                ## Get the data type and remove the scope portion
                my $dtype = $1;
                my @ns;
                if ($dtype =~ s/(.*):://) {
                  @ns = split(/::/, $1);
                }

                ## For now, we will assume that all parts of the scope
                ## name are modules.  If idl2jni is extended to support
                ## types declared within interfaces, this code will need
                ## to change.
                foreach my $ns (@ns) {
                  $ts_str .= "module $ns { ";
                }

                $ts_str .= "native ${dtype}Seq; " .
                           "local interface ${dtype}TypeSupport {}; " .
                           "local interface ${dtype}DataWriter {}; " .
                           "local interface ${dtype}DataReader {}; " .
                           "const long ${dtype}TypeSupportImpl = 0; ";
                ## FooTypeSupportImpl is not a constant, but we'll generate the
                ## correct mapping to .java files as if it were a constant.

                ## Close the namespaces (module or interface it works the
                ## same).
                foreach my $ns (@ns) {
                  $ts_str .= " };";
                }
              }
            }
          }
        }
        elsif ($line =~ s/^import\s+([^;]+)\s*;//) {
          ## The import keyword is similar to #include, so we're handling
          ## it here.  This is probably not fool proof, but it will
          ## probably handle most situations where it's used.
          my $file = $1;
          $file =~ s/\s+$//;
          $file .= '.idl';

          $self->include_file($file, $includes, $macros, $mparams);
        }

        if (!$$skip[scalar(@$skip) - 1] && !$included) {
          $contents .= ' ' . $self->replace_macros($macros, $mparams, $line);
        }
      }
    }
    close($fh);
  }
  elsif (defined $self->{'strs'}->{$file} && !$included) {
    $contents = delete $self->{'strs'}->{$file};
  }

  return $contents, $ts_str;
}

sub include_file {
  my($self, $file, $includes, $macros, $mparams) = @_;

  ## Look for the include file in the user provided include paths
  foreach my $incpath ('.', @$includes) {
    if (-r "$incpath/$file") {
      return $self->preprocess(($incpath eq '.' ? '' : "$incpath/") . $file,
                               $includes, $macros, $mparams, 1);
    }
  }

  return '';
}

sub evaluate_if {
  my($self, $macros, $value) = @_;
  my $status = 1;

  ## Remove leading and trailing spaces
  $value =~ s/^\s+//;
  $value =~ s/\s+$//;

  ## Split up parenthesis
  if (index($value, '(') == 0) {
    my $count  = 0;
    my $length = length($value);
    for(my $i = 0; $i < $length; $i++) {
      my $c = substr($value, $i, 1);
      if ($c eq '(') {
        $count++;
      }
      elsif ($c eq ')') {
        $count--;
        if ($count == 0) {
          my $val = substr($value, 1, $i - 1);
          my $ret = $self->evaluate_if($macros, $val);
          substr($value, 0, $i + 1) = $ret;
          last;
        }
      }
    }
  }

  ## Handle OR and AND by recursively calling this method using the
  ## built-in process of these operators.
  if ($value =~ /(\|\||&&)/) {
    my $op   = $1;
    my $loc  = index($value, $op);
    my $part = substr($value, 0, $loc);
    my $rest = substr($value, $loc + 2);
    if ($op eq '||') {
      $status = $self->evaluate_if($macros, $part) ||
                $self->evaluate_if($macros, $rest);
    }
    else {
      $status = $self->evaluate_if($macros, $part) &&
                $self->evaluate_if($macros, $rest);
    }
  }
  else {
    ## For #if, we only support defined, macro and numeric values.
    ## All others are considered a syntax error.
    if ($value =~ /^(!)?\s*defined\s*\(\s*([_a-z]\w*)\s*\)$/i) {
      my $not   = $1;
      my $macro = $2;
      $status = (defined $macros->{$macro} ? 1 : 0);
      $status = !$status if ($not);
    }
    elsif ($value =~ /^([_a-z]\w*)\s*([=!]=)\s*(\d+)$/i) {
      my $macro = $1;
      my $not   = ($2 eq '!=');
      my $val   = $3;
      $status = (defined $macros->{$macro} &&
                 $macros->{$macro} eq $val ? 1 : 0);
      $status = !$status if ($not);
    }
    elsif ($value =~ /^\d+$/) {
      $status = ($value ? 1 : 0);
    }
    else {
      ## Syntax error in #if
      $status = 0;
    }
  }
  return $status;
}

sub replace_macros {
  my($self, $macros, $mparams, $line) = @_;
  foreach my $macro (keys %$macros) {
    ## For each macro provided by the user, see if it has been used
    ## anywhere in this line.
    while ($line =~ /\b$macro\b/) {
      ## Replace the corresponding parameter names with the correct
      ## values obtained above.
      my(@strings, @dstrings);
      my $escaped = ($line =~ s/\\\"/\01/g);
      $escaped |= ($line =~ s/\\\'/\02/g);
      while($line =~ s/('[^']+')/\04/) {
        push(@strings, $1);
      }
      while($line =~ s/("[^"]+")/\03/) {
        push(@dstrings, $1);
      }

      ## It has been used, so save the value for later
      my $val = $macros->{$macro};

      if (defined $mparams->{$macro}) {
        ## See the user provided macro takes parameters
        if ($line =~ /\b($macro\s*\()/) {
          ## Gather up the macro parameters
          my $start  = $1;
          my $length = length($line);
          my $count  = 1;
          my $uses   = index($line, $start);
          my $usee   = $length;
          my $p      = $uses + length($start);
          my @params;
          for(my $i = $p; $i < $length; $i++) {
            my $c = substr($line, $i, 1);
            if ($c eq '(') {
              $count++;
            }
            elsif ($c eq ',' || $c eq ')') {
              if ($c eq ')') {
                $count--;
                if ($count == 0) {
                  $usee = $i + 1;
                }
                else {
                  ## This isn't the end of the paramters, so keep going
                  next;
                }
              }
              elsif ($count > 1) {
                ## This is a not a parameter marker since we are inside a
                ## set of parenthesis.
                next;
              }

              ## We've reached the last parenthesis, so add this to the
              ## list of parameters after stripping off leading and
              ## trailing white space.
              my $param = substr($line, $p, ($i - $p));
              $param =~ s/^\s+//;
              $param =~ s/\s+$//;
              push(@params, $param);

              ## Set the starting point for the next parameter to the
              ## character just after the current closing parenthesis.
              $p = $i + 1;
            }
          }

          my $i = 0;
          foreach my $param (@{$mparams->{$macro}}) {
            my $pval = $params[$i];
            $val =~ s/\b$param##/$pval/g;
            $val =~ s/##$param\b/$pval/g;
            $val =~ s/\b$param\b/$pval/g;
            $i++;
          }

          ## Replace the macro call with the expanded macro value
          substr($line, $uses, $usee - $uses) = $val;
        }
      }
      else {
        ## There were no macro paramters, so just do a simple search and
        ## replace.
        $line =~ s/\b$macro\b/$val/g;
      }

      ## We will need to leave the loop if we do not see any instances of
      ## the current macro.  We save the indicator so that we can replace
      ## strings before leaving.
      my $leave = ($line !~ /\b$macro\b/);

      ## Replace the escaped characters with the right values.
      foreach my $dstring (@dstrings) {
        $line =~ s/\03/$dstring/;
      }
      foreach my $string (@strings) {
        $line =~ s/\04/$string/;
      }
      if ($escaped) {
        $line =~ s/\01/\\"/g;
        $line =~ s/\02/\\'/g;
      }

      last if ($leave);
    }
  }
  return $line;
}

1;
