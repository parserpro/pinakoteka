package Functions::Util;
use common::sense;
use POSIX;
use LWP::UserAgent;
use GD;
use Image::Magick;
use Net::SMTP;
use HTTP::BrowserDetect;
use utf8::all;
use Encode;
use Data::Dumper;

## БРАУЗЕРЫ
# проверка на устаревший браузер
sub is_browser_old {
    my $user_agent_string = shift;
    my $old     = 0;
    my $browser = HTTP::BrowserDetect->new($user_agent_string);

    $old = 1 if $browser->ie      && $browser->version <= 7;
    $old = 1 if $browser->firefox && $browser->version <= 3;

    return $old;
}

##

# генерация алфавита со ссылками
sub get_admin_person_letters {
    my ($controller, $sel_letter, $eng_letters) = @_;
    $sel_letter = 'ВСЕ' if $sel_letter eq '';
    my @symbols = ('А','Б','В','Г','Д','Е','Ж','З','И','К','Л','М','Н','О','П','Р','С','Т','У','Ф','Х','Ц','Ч','Ш','Щ','Э','Ю','Я','ВСЕ');

    if ( $eng_letters ) {
        @symbols = (@symbols, ('A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','V','W','X','Y','Z'));
    }

    my $letters;

    for my $letter ( @symbols ) {
        my $letter_link = "?letter=$letter";
        my $lastletter;

        if ($letter eq "ВСЕ") {
            $lastletter = "&nbsp;&nbsp;&nbsp;";
            $letter_link = "";
        }

        if ($letter ne $sel_letter) {
            $letters .= qq( $lastletter<a href="/admin/${controller}list$letter_link">$letter</a> );
        }
        else {
            $letters .= "$lastletter [$letter]";
        }
    }

    return $letters;
}

# загрузить контент с сайта
sub get_file_from_url {
    my $url = shift;
    my $timeout = shift || 0;

    return 0 unless $url;

    my $ua = LWP::UserAgent->new;
    if ( $timeout ) { $ua->timeout($timeout) };
    my $tx = $ua->get($url);

    if ( $tx->is_success ) {
        my $file = $tx->decoded_content;
        return $file;
    }
    else {
        warn "cannot download file from url: $url: ";
        return;
    }
}

# загрузить контент с сайта POST
# используется для импорта обложки с bgshop
sub get_file_from_url_post {
    my ($url, $post) = split(/\?/,$_[0]);

    return unless $url;

    my $ua = LWP::UserAgent->new;
    my $req = HTTP::Request->new(POST => $url);
    $req->content_type('application/x-www-form-urlencoded');
    $req->content($post);
    my $res = $ua->request($req);

    if ($res->status_line =~ /302/ or $res->is_success) {
        return $res->content;
    }
    else {
        warn "cannot upload image from url: $url";
        return;
    }
}

sub resize_image {
    my ($filename, $filepath_out, $width, $height) = @_;

    GD::Image->trueColor(1);

    unless ( -e $filename ) { warn "file '$filename' does not exist"; }
    my $gd = GD::Image->new($filename) or warn "wrong image format";

    my $k_h = $height / $gd->height;
    my $k_w = $width / $gd->width;
    my $k = ($k_h < $k_w ? $k_h : $k_w);
    $height = int($gd->height * $k);
    $width  = int($gd->width * $k);

    my $image = GD::Image->new($width, $height);
    $image->copyResampled(
        $gd,
        0, 0,
        0, 0,
        $width, $height,
        $gd->width, $gd->height
    );

    save_image_from_data($filepath_out, $image->jpeg(95));

    return { height => $height, width => $width };
}

sub save_image_from_data {
    my ($filename, $data) = @_;

    return 0 unless $data && $filename;

    open(my $F, '>', $filename) or warn "cannot save image to: $filename";
    binmode $F;
    print $F $data;
    close $F;

    return $filename;
}

# TODO: не могу изменять размер картинки
# TODO: не могу преобразовывать форматы картинок
sub save_image_from_url {
    my ($url, $filename) = @_;

    return 0 unless $url && $filename;

    my $ua = LWP::UserAgent->new;
    my $tx = $ua->get($url);

    if ( $tx->is_success ) {
        my $file = $tx->decoded_content;
        save_image_from_data($filename, $file);
    }
    else {
        warn "save_image_from_url: cannot upload image from url: $url";
        return 0;
    }

    return $filename;
}

sub check_image_exists {
    my $url = shift;

    my $mojo     = $Fantlab::mojo;
    my $imagedir = $mojo->config->{imagedir};

    my $is_exists = -f "$imagedir/$url";

    return $is_exists;
}

sub delete_image_from_disc {
    my $path = shift;

    my $mojo     = $Fantlab::mojo;
    my $imagedir = $mojo->config->{imagedir};

    unlink "$imagedir/$path";

    return 1;
}

# запись картинки на диск (данные, путь)
sub save_image_to_disc {
    my ($image, $url, $is_url) = @_;
    return unless $image || $url;

    my $mojo     = $Fantlab::mojo;
    my $imagedir = $mojo->config->{imagedir};

    open(my $file, '>', "$imagedir/$url");
    binmode($file);
    my $buff;

    if ($is_url != 1) {
        while (read($image,$buff,2096)) { print $file $buff; }
    }
    else {
        $buff = AdminGet::AdminSiteContent($image);
        print $file $buff;
    }

    close F;
    chmod 0640, "$imagedir/$url";
}

# создание превью, определенного размера
sub create_preview_image {
    my ($img, $img_small, $small_width, $small_height) = @_;
    return unless ($img or $img_small);

    my $mojo     = $Fantlab::mojo;
    my $imagedir = $mojo->config->{imagedir};

    #превью
    my $image = Image::Magick->new;
    my $x = $image->Read("$imagedir/$img");

    $image->Resize(
        width => $small_width,
        height => $small_height
    );

    $x = $image->Write("$imagedir/$img_small");
    chmod 0640, "$imagedir/$img_small";
}

# отправка сообщения по электронной почте
sub send_email {
    my ($to, $from, $subject, $body) = @_;

    my $message = qq{To: $to
From: $from
Content-Type: text/plain; charset=utf-8
Content-Transfer-Encoding: 8bit
Subject: $subject

$body
    };

    return unless $Fantlab::mojo->config->{is_sendmail_enabled};

    my $smtp = Net::SMTP->new('localhost');
    $smtp->mail($from);
    $smtp->to($to);
    $smtp->data;
    $smtp->datasend($message);
    $smtp->dataend;
    $smtp->quit;
}

sub clean_utf_8 {
    my $string = shift;

    my $utf8_encoded = '';

    eval {
        $utf8_encoded = Encode::encode('UTF-8', $string, Encode::FB_CROAK);
    };

    if ($@) {
        # sanitize malformed UTF-8
        $utf8_encoded = '';
        my @chars = split(//, $string);
        foreach my $char (@chars) {
            my $utf_8_char = eval { Encode::encode('UTF-8', $char, Encode::FB_CROAK) }
                or next;
            $utf8_encoded .= $utf_8_char;
        }
    }

    return Encode::decode('UTF-8', $utf8_encoded);
}

1;