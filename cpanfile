requires 'perl', '5.008001';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

requires 'File::Spec::Functions';
requires 'Getopt::Compact';
requires 'XML::DOM';
requires 'XML::Generator';
