@rem = '--*-Perl-*--
@echo off
if "%OS%" == "Windows_NT" goto WinNT
perl -x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
goto endofperl
:WinNT
perl -x -S %0 %*
if NOT "%COMSPEC%" == "%SystemRoot%\system32\cmd.exe" goto endofperl
if %errorlevel% == 9009 echo You do not have Perl in your PATH.
if errorlevel 1 goto script_failed_so_exit_with_non_zero_val 2>nul
goto endofperl
@rem ';
#!/usr/local/bin/perl -w
#line 15
use strict;
use Socket;
use IO::Socket;
use Cwd;
use Getopt::Long;

use vars qw($VERSION $portfile);
$VERSION = sprintf '4.%03d', q$Revision: #29 $ =~ /\D(\d+)\s*$/;

my %opt;
INIT
 {
  my $home = $ENV{'HOME'} || $ENV{'HOMEDRIVE'}.$ENV{'HOMEPATH'};
  $portfile = "$home/.ptkedsn";
  my $port = $ENV{'PTKEDPORT'};
  return if $^C;
  GetOptions(\%opt,qw(server! encoding=s));
  unless (defined $port)
   {
    if (open(SN,"$portfile"))
     {
      $port = <SN>;
      close(SN);
     }
   }
  if (defined $port)
   {
    my $sock = IO::Socket::INET->new(PeerAddr => 'localhost',
               PeerPort => $port, Proto    => 'tcp');
    if ($sock)
     {
      binmode($sock);
      $sock->autoflush;
      foreach my $file (@ARGV)
       {
        unless  (print $sock "$file\n")
         {
          die "Cannot print $file to socket:$!";
         }
        print "Requested '$file'\n";
       }
      $sock->close || die "Cannot close socket:$!";
      exit(0);
     }
    else
     {
      warn "Cannot connect to server on $port:$!";
     }
   }
 }

use Tk;
use Tk::DropSite qw(XDND Sun);
use Tk::DragDrop qw(XDND Sun);
use Tk::widgets qw(TextUndo Scrollbar Menu Dialog);
# use Tk::ErrorDialog;

{
 package Tk::TextUndoPtked;
 @Tk::TextUndoPtked::ISA = qw(Tk::TextUndo);
 Construct Tk::Widget 'TextUndoPtked';

 sub Save {
  my $w = shift;
  $w->SUPER::Save(@_);
  $w->toplevel->title($w->FileName);
 }

 sub Load {
  my $w = shift;
  $w->SUPER::Load(@_);
  $w->toplevel->title($w->FileName);
 }

 sub MenuLabels { shift->SUPER::MenuLabels, 'Encoding' }

 sub Encoding
 {
  my ($w,$enc) = @_;
  if (@_ > 1)
   {
    $enc = $w->getEncoding($enc) unless ref($enc);
    $w->{ENCODING} = $enc;
    $enc = $enc->name;
    $w->PerlIO_layers(":encoding($enc)");
   }
  return $w->{ENCODING};
 }

 sub EncodingMenuItems
 {
  my ($w) = @_;
  return [ [ command => 'System', -command => [ $w, Encoding => Tk::SystemEncoding()->name ]],
           [ command => 'UTF-8',  -command => [ $w, Encoding => 'UTF-8'] ],
           [ command => 'iso-8859-1', -command => [ $w, Encoding => 'iso8859-1'] ],
           [ command => 'iso-8859-15', -command => [ $w, Encoding => 'iso8859-15'] ],
         ];

 }

}

my $top = MainWindow->new();

if ($opt{'server'})
 {
  my $sock = IO::Socket::INET->new(Listen => 5, Proto => 'tcp');
  die "Cannot open listen socket:$!" unless defined $sock;
  binmode($sock);

  my $port = $sock->sockport;
  $ENV{'PTKEDPORT'} = $port;
  open(SN,">$portfile") || die "Cannot open $portfile:$!";
  print SN $port;
  close(SN);
  print "Accepting connections on $port\n";
  $top->fileevent($sock,'readable',
  sub
  {
   print "accepting $sock\n";
   my $client = $sock->accept;
   if (defined $client)
    {
     binmode($client);
     print "Connection $client\n";
     $top->fileevent($client,'readable',[\&EditRequest,$client]);
    }
   });
 }

Tk::Event::HandleSignals();
$SIG{'INT'} = sub { $top->WmDeleteWindow };

$top->iconify;
$top->optionAdd('*TextUndoPtked.Background' => '#fff5e1');
$top->fontCreate('ptked',-family => 'courier', -size => ($^O eq 'MSWin32' ? 11 : -12),
                 -weight => 'normal', -slant => 'roman');
$top->optionAdd('*TextUndoPtked.Font' => 'ptked');

foreach my $file (@ARGV)
 {
  Create_Edit($file);
 }


sub EditRequest
{
 my ($client) = @_;
 local $_;
 while (<$client>)
  {
   chomp($_);
   print "'$_'\n",
   Create_Edit($_);
  }
 warn "Odd $!" unless eof($client);
 $top->fileevent($client,'readable','');
 print "Close $client\n";
 $client->close;
}

MainLoop;
unlink("$portfile");
exit(0);

sub Create_Edit
{
 my $path = shift;
 my $ed   = $top->Toplevel(-title => $path);
 $ed->withdraw;
 $top->{'Edits'}++;
 $ed->OnDestroy([\&RemoveEdit,$top]);
 my $t = $ed->Scrolled('TextUndoPtked', -wrap => 'none',
           -scrollbars => 'se', # both required till optional fixed!
         );
 $t->pack(-expand => 1, -fill => 'both');
 $t = $t->Subwidget('scrolled');

 $t->Encoding($opt{encoding}) if $opt{encoding};

 my $menu = $t->menu;
 $menu->cascade(-label => '~Help', -menuitems => [
                [Button => '~About...', -command => [\&About,$ed]],
               ]);
 $ed->configure(-menu => $menu);
 my $dd = $t->DragDrop(-event => '<Meta-B1-Motion>');
 $t->bind(ref($t),'<Meta-B1-Motion>',\&Ouch);
 $t->bind(ref($t),'<Meta-ButtonPress>',\&Ouch);
 $t->bind(ref($t),'<Meta-ButtonRelease>',\&Ouch);
 $dd->configure(-startcommand =>
                sub
                 {
                  return 1 unless (eval { $t->tagNextrange(sel => '1.0','end')});
                  $dd->configure(-text => $t->get('sel.first','sel.last'));
                 });

 $t->DropSite(-motioncommand =>
               sub
                { my ($x,$y) = @_;
                  $t->markSet(insert => "\@$x,$y");
                },
               -dropcommand => [\&HandleDrop,$t],
              );



 $ed->protocol('WM_DELETE_WINDOW',[ConfirmExit => $t]);
 $t->bind('<F3>',\&DoFind);

 $ed->idletasks;
 if (-e $path)
  {
   $t->Load($path);
  }
 else
  {
   $t->FileName($path);
  }
 $ed->deiconify;
 $t->update;
 $t->focus;
}

sub Ouch
{
 warn join(',','Ouch',@_);
}

sub RemoveEdit
{
 my $top = shift;
 if (--$top->{'Edits'} == 0)
  {
   $top->destroy unless $opt{'s'};
  }
}

sub HandleDrop
{my ($t,$seln,$x,$y) = @_;
 # warn join(',',Drop => @_);
 my $string;
 Tk::catch { $string = $t->SelectionGet(-selection => $seln,'FILE_NAME') };
 if ($@)
  {
   Tk::catch { $string = $t->SelectionGet(-selection => $seln) };
   if ($@)
    {
     my @targets = $t->SelectionGet(-selection => $seln, 'TARGETS');
     $t->messageBox(-text => "Targets : ".join(' ',@targets));
    }
   else
    {
     $t->markSet(insert => "\@$x,$y");
     $t->insert(insert => $string);
    }
  }
 else
  {
   Create_Edit($string);
  }
}


my $str;

sub DoFind
{
 my $t = shift;
 $str = shift if (@_);
 my $posn = $t->index('insert+1c');
 $t->tag('remove','sel','1.0','end');
 local $_;
 while ($t->compare($posn,'<','end'))
  {
   my ($line,$col) = split(/\./,$posn);
   $_ = $t->get("$line.0","$posn lineend");
   pos($_) = $col;
   if (/\G(.*)$str/g)
    {
     $col += length($1);
     $posn = "$line.$col";
     $t->SetCursor($posn);
     $t->tag('add','sel',$posn,"$line.".pos($_));
     $t->focus;
     return;
    }
   $posn = $t->index("$posn lineend + 1c");
  }
}

sub AskFind
{
 my ($t) = @_;
 unless (exists $t->{'AskFind'})
  {
   my $d = $t->{'AskFind'} = $t->Toplevel(-popover => 'cursor', -popanchor => 'nw');
   $d->title('Find...');
   $d->withdraw;
   $d->transient($t->toplevel);
   my $e = $d->Entry->pack;
   $e->bind('<Return>', sub { $d->withdraw; DoFind($t,$e->get); });
   $d->protocol(WM_DELETE_WINDOW =>[withdraw => $d]);
  }
 $t->{'AskFind'}->Popup;
 $t->update;
 $t->{'AskFind'}->focusNext;
}

sub About
{
 my $mw = shift;

 $mw->Dialog(-text => <<"END",-popover => $mw)->Show;
$0 version $VERSION
perl$]/Tk$Tk::VERSION

Copyright � 1995-2004 Nick Ing-Simmons. All rights reserved.
This package is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.
END
}

__END__

=head1 NAME

ptked - an editor in Perl/Tk

=head1 SYNOPSIS

S<  >B<ptked> [I<file-to-edit>]

=head1 DESCRIPTION

B<ptked> is a simple text editor based on perl/Tk's TextUndo widget.

=cut








__END__
:endofperl
