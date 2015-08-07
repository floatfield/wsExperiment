require('coffee-script/register');
var gulp = require('gulp'),
  gutil = require('gulp-util'),
  coffee = require('gulp-coffee'),
  mocha = require('gulp-mocha');

gulp.task('mocha', ['coffee'], function() {
  return gulp.src(['test/*.coffee'], {
      read: false
    })
    .pipe(coffee({
      bare: true
    }).on('error', gutil.log))
    .pipe(mocha({
      reporter: 'spec'
    })).once('end', function() {
      process.exit();
    });
});

gulp.task('coffee', function() {
  return gulp.src('coffee/*.coffee')
    .pipe(coffee({
      bare: true
    }).on('error', gutil.log))
    .pipe(gulp.dest('lib/'));
});

gulp.task('mocha-watch', function() {
  gulp.watch(['test/**', 'coffee/**'], ['mocha']);
});

gulp.task('coffee-test', function(){
  return gulp.src('test/*.coffee')
    .pipe(coffee({
      bare: true
    }).on('error', gutil.log))
    .pipe(gulp.dest('test_js/'));
});
