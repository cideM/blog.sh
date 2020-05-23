BEGIN {
    FS = ":";
}

/^-+$/ {
    if (START_READING) {
        START_READING=0;
    } else {
        START_READING=1;
        next;
    }
}

{
    if (START_READING) {
        print $2; 
    }
}
