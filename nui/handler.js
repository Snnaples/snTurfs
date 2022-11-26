

const closeS = () => $('body').fadeOut('slow')

function addKill(killer, killed, weapon,killerColor,mortColor) {

    if(killer.length >= 15 || killed.length >= 15) {
        $('body').fadeIn('normal')
        $('.playerlist').hide()
        $('<div class="killContainer"><span ' + `style="color:${killerColor}; font-size: 9px;"` + ' >' + killer + '</span><img src="./img/' + weapon + '.webp" class="weapon"><span '+ `style="color:${mortColor}; font-size: 9px;"`+ ' >' + killed + '</span></div><br class="clear">').appendTo('.killss')
        //.css({'margin-right':-$(this).width()+'px'})
        .animate({'margin-right':-$(this).width()+'px'}, 'slow')
        .delay(5000)
        .queue(function() { $(this).remove(); });
    } else {
        $('body').fadeIn('normal')
        $('.playerlist').hide()
        $('<div class="killContainer"><span ' + `style="color:${killerColor}"` + ' >' + killer + '</span><img src="./img/' + weapon + '.webp" class="weapon"><span '+ `style="color:${mortColor}"`+ ' >' + killed + '</span></div><br class="clear">').appendTo('.killss')
        //.css({'margin-right':-$(this).width()+'px'})
        .animate({'margin-right':-$(this).width()+'px'}, 'slow')
        .delay(5000)
        .queue(function() { $(this).remove(); });
    }
}


$(function() {

    window.addEventListener('message', function(event) {
        if(event.data.type == 'newKill') {
           return addKill(event.data.killer, event.data.killed, event.data.weapon,event.data.killerColor,event.data.mortColor);   
        }

        if(event.data.type == 'close') return closeS();
        if(event.data.type == 'reset') return $('#playerlist').html(' ');


        if(event.data.type =='show') {
            $('.playerlist').fadeIn('normal')
            $('body').fadeIn('normal')

            $('#playerlist').html('');
            for (let html of event.data.scoreboard) {
                $('#playerlist').append(html.html);
            }

        }

    })



})

