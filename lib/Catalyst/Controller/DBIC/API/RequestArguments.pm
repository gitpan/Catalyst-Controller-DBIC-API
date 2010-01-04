package Catalyst::Controller::DBIC::API::RequestArguments;
our $VERSION = '1.004001';
use MooseX::Role::Parameterized;
use Catalyst::Controller::DBIC::API::Types(':all');
use MooseX::Types::Moose(':all');
use Data::Dumper;
use namespace::autoclean;

requires qw/check_has_relation check_column_relation/;

with 'MooseX::Role::BuildInstanceOf' =>
{
    'target' => 'Catalyst::Controller::DBIC::API::Validator',
    'prefix' => 'search_validator',
};

with 'MooseX::Role::BuildInstanceOf' =>
{
    'target' => 'Catalyst::Controller::DBIC::API::Validator',
    'prefix' => 'select_validator',
};

with 'MooseX::Role::BuildInstanceOf' =>
{
    'target' => 'Catalyst::Controller::DBIC::API::Validator',
    'prefix' => 'prefetch_validator',
};

parameter static => ( isa => Bool, default => 0 );

role {
    
    my $p = shift;

    has 'count' =>
    (
        is => 'ro',
        writer => '_set_count',
        isa => Int,
        predicate => 'has_count',
        traits => ['Aliased'],
        alias => 'list_count'
    );

    has 'page' =>
    (
        is => 'ro',
        writer => '_set_page',
        isa => Int,
        predicate => 'has_page',
        traits => ['Aliased'],
        alias => 'list_page'
    );

    has 'ordered_by' =>
    (
        is => 'ro',
        writer => '_set_ordered_by',
        isa => OrderedBy,
        predicate => 'has_ordered_by',
        traits => ['Aliased'],
        coerce => 1,
        default => sub { $p->static ? [] : undef },
        alias => 'list_ordered_by',
    );

    has 'grouped_by' =>
    (
        is => 'ro',
        writer => '_set_grouped_by',
        isa => GroupedBy,
        predicate => 'has_grouped_by',
        traits => ['Aliased'],
        coerce => 1,
        default => sub { $p->static ? [] : undef },
        alias => 'list_grouped_by',
    );

    has prefetch =>
    (
        is => 'ro',
        writer => '_set_prefetch',
        isa => Prefetch, 
        default => sub { $p->static ? [] : undef },
        coerce => 1,
        trigger => sub
        {
            my ($self, $new) = @_;
            if($self->has_prefetch_allows and @{$self->prefetch_allows})
            {
                foreach my $pf (@$new)
                {
                    if(HashRef->check($pf))
                    {
                        die qq|'${\Dumper($pf)}' is not an allowed prefetch in: ${\join("\n", @{$self->prefetch_validator->templates})}|
                            unless $self->prefetch_validator->validate($pf)->[0];
                    }
                    else
                    {
                        die qq|'$pf' is not an allowed prefetch in: ${\join("\n", @{$self->prefetch_validator->templates})}|
                            unless $self->prefetch_validator->validate({$pf => 1})->[0];
                    }
                }
            }
            else
            {
                return if not defined($new);
                die 'Prefetching is not allowed' if @$new;
            }
        },
        traits => ['Aliased'],
        alias => 'list_prefetch',
    );

    has prefetch_allows =>
    (
        is => 'ro',
        writer => '_set_prefetch_allows',
        isa => ArrayRef[ArrayRef|Str|HashRef], 
        default => sub { [ ] },
        predicate => 'has_prefetch_allows',
        trigger => sub
        {
            my ($self, $new) = @_;

            sub check_rel {
                my ($self, $rel, $static) = @_;
                if(ArrayRef->check($rel))
                {
                    foreach my $rel_sub (@$rel)
                    {
                        $self->check_rel($rel_sub, $static);
                    }
                }
                elsif(HashRef->check($rel))
                {
                    while(my($k,$v) = each %$rel)
                    {
                        $self->check_has_relation($k, $v, undef, $static);
                    }
                    $self->prefetch_validator->load($rel);
                }
                else
                {
                    $self->check_has_relation($rel, undef, undef, $static);
                    $self->prefetch_validator->load($rel);
                }
            }

            foreach my $rel (@$new)
            {
                $self->check_rel($rel, $p->static);
            }
        },
        traits => ['Aliased'],
        alias => 'list_prefetch_allows',
    );

    has 'search_exposes' =>
    (
        is => 'ro',
        writer => '_set_search_exposes',
        isa => ArrayRef[Str|HashRef],
        predicate => 'has_search_exposes',
        traits => ['Aliased'],
        default => sub { [ ] },
        alias => 'list_search_exposes',
        trigger => sub
        {
            my ($self, $new) = @_;
            $self->search_validator->load($_) for @$new;
        },
    );

    has 'search' =>
    (
        is => 'ro',
        writer => '_set_search',
        isa => HashRef,
        predicate => 'has_search',
        trigger => sub
        {
            my ($self, $new) = @_;
            
            if($self->has_search_exposes and @{$self->search_exposes})
            {
                while( my ($k, $v) = each %$new)
                {
                    local $Data::Dumper::Terse = 1;
                    die qq|{ $k => ${\Dumper($v)} } is not an allowed search term in: ${\join("\n", @{$self->search_validator->templates})}|
                        unless $self->search_validator->validate({$k=>$v})->[0];
                }
            }
            else
            {
                while( my ($k, $v) = each %$new)
                {
                    $self->check_column_relation({$k => $v});
                }
            }
        },
    );

    has 'select_exposes' =>
    (
        is => 'ro',
        writer => '_set_select_exposes',
        isa => ArrayRef[Str|HashRef],
        predicate => 'has_select_exposes',
        default => sub { [ ] },
        traits => ['Aliased'],
        alias => 'list_returns_exposes',
        trigger => sub
        {
            my ($self, $new) = @_;
            $self->select_validator->load($_) for @$new;
        },
    );

    has select =>
    (
        is => 'ro',
        writer => '_set_select',
        isa => SelectColumns,
        default => sub { $p->static ? [] : undef },
        traits => ['Aliased'],
        alias => 'list_returns',
        coerce => 1,
        trigger => sub
        {   
            my ($self, $new) = @_;
            if($self->has_select_exposes)
            {
                foreach my $val (@$new)
                {
                    die "'$val' is not allowed in a select"
                        unless $self->select_validator->validate($val);
                }
            }
            else
            {
                $self->check_column_relation($_, $p->static) for @$new;
            }
        },
    );

    has 'request_data' =>
    (
        is => 'ro',
        writer => '_set_request_data',
        isa => HashRef,
    );
};

1;
