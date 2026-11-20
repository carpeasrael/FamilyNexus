ObjC.import('ApplicationServices');
function run(argv){ var dy=parseInt(argv[0]); var ev=$.CGEventCreateScrollWheelEvent(null,0,1,dy); $.CGEventPost(0,ev); }
